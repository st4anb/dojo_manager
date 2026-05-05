const { MercadoPagoConfig, Payment } = require('mercadopago');
const admin = require('firebase-admin');

// Inicializa Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert({
      projectId: process.env.FIREBASE_PROJECT_ID,
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
    }),
  });
}

const db = admin.firestore();
const client = new MercadoPagoConfig({ accessToken: process.env.MP_ACCESS_TOKEN });

export default async function handler(req, res) {
  // 1. Resposta imediata ao Mercado Pago para evitar reenvios
  res.status(200).send('OK');

  if (req.method !== 'POST') return;

  try {
    const { action, data } = req.body;

    // Interessado apenas em pagamentos (created ou updated)
    if (action === 'payment.created' || action === 'payment.updated' || req.body.type === 'payment') {
      const paymentId = data?.id || req.body.data?.id;

      if (!paymentId) return;

      // 2. Busca detalhes reais na SDK do Mercado Pago para evitar fakes
      const payment = new Payment(client);
      const paymentData = await payment.get({ id: paymentId });

      if (paymentData.status === 'approved') {
        const order_nsu = paymentData.external_reference; // Nosso UUID
        
        if (!order_nsu) {
          console.error(`Pagamento ${paymentId} sem external_reference.`);
          return;
        }

        // 3. Busca o registro do pagamento para saber quem é o aluno
        const paymentRef = db.collection('PAGAMENTOS').doc(order_nsu);
        const paymentDoc = await paymentRef.get();

        if (!paymentDoc.exists) {
          console.error(`Referência ${order_nsu} não encontrada no Firestore.`);
          return;
        }

        const { alunoId, status: currentStatus } = paymentDoc.data();

        // Evita processar se já estiver pago (idempotência)
        if (currentStatus === 'pago' || currentStatus === 'approved') {
          console.log(`Pagamento ${order_nsu} já havia sido processado.`);
          return;
        }

        // 4. Update Atômico (Batch)
        const batch = db.batch();

        // A) Atualiza status na coleção global de pagamentos
        batch.update(paymentRef, {
          status: 'pago',
          paymentIdMP: paymentId,
          pagoEm: admin.firestore.FieldValue.serverTimestamp(),
          metodo: paymentData.payment_method_id,
        });

        // B) Atualiza o documento do Aluno (Status 'em dia' + 30 dias)
        const studentRef = db.collection('ALUNOS').doc(alunoId);
        const nextDueDate = new Date();
        nextDueDate.setDate(nextDueDate.getDate() + 30);

        batch.update(studentRef, {
          'financeiro.statusPagamento': 'em dia',
          'financeiro.ultimaConfirmacao': admin.firestore.FieldValue.serverTimestamp(),
          'financeiro.proximoVencimento': admin.firestore.Timestamp.fromDate(nextDueDate),
          'financeiro.linkPagamento': admin.firestore.FieldValue.delete(), // Remove link pendente
        });

        // C) Atualiza o histórico financeiro do aluno
        const historyRef = db.collection('ALUNOS').doc(alunoId).collection('historico_pagamentos').doc(order_nsu);
        batch.update(historyRef, {
          status: 'pago',
          pagoEm: admin.firestore.FieldValue.serverTimestamp(),
          titulo: 'Mensalidade Paga ✅'
        });

        await batch.commit();
        console.log(`Sucesso: Pagamento ${order_nsu} processado para o aluno ${alunoId}.`);
      }
    }
  } catch (error) {
    console.error('Erro no processamento do Webhook:', error);
  }
}
