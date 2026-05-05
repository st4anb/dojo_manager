import { VercelRequest, VercelResponse } from '@vercel/node';
import admin from 'firebase-admin';

// Inicialize o Firebase Admin (certifique-se de configurar as variáveis de ambiente no Vercel)
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

export default async function handler(req: VercelRequest, res: VercelResponse) {
  // 1. RESPOSTA IMEDIATA: O Mercado Pago exige um 200 OK rápido para evitar reenvios
  // Enviamos o 200 imediatamente, mas a função continuará executando no Vercel
  res.status(200).send('OK');

  if (req.method !== 'POST') return;

  try {
    const { action, data } = req.body;

    // Apenas nos interessa a ação de criação/atualização de pagamento
    if (action === 'payment.created' || action === 'payment.updated') {
      const paymentId = data.id;

      // 2. BUSCA STATUS NO MERCADO PAGO
      // É mais seguro consultar a API do MP do que confiar apenas no payload do webhook
      const mpResponse = await fetch(`https://api.mercadopago.com/v1/payments/${paymentId}`, {
        headers: {
          'Authorization': `Bearer ${process.env.MP_ACCESS_TOKEN}`,
        },
      });

      if (!mpResponse.ok) return;
      const paymentData = await mpResponse.json();

      if (paymentData.status === 'approved') {
        const alunoId = paymentData.external_reference;

        // 3. REGRA DE IDEMPOTÊNCIA: Verifica se o pagamento já foi processado no Firestore
        const paymentRef = db.collection('PAGAMENTOS').doc(paymentId.toString());
        const doc = await paymentRef.get();

        if (doc.exists && doc.data()?.status === 'approved') {
          console.log(`Pagamento ${paymentId} já processado anteriormente.`);
          return;
        }

        // 4. ATUALIZAÇÃO ATÔMICA (BATCH)
        const batch = db.batch();
        
        // Registrar na coleção de pagamentos (Global)
        batch.set(paymentRef, {
          aluno_id: alunoId,
          payment_id: paymentId,
          status: 'approved',
          valor: paymentData.transaction_amount,
          data: admin.firestore.FieldValue.serverTimestamp(),
          metodo: 'pix',
        }, { merge: true });

        // Registrar na subcoleção historico_pagamentos do aluno
        const historyRef = db.collection('ALUNOS').doc(alunoId).collection('historico_pagamentos').doc(paymentId.toString());
        batch.set(historyRef, {
          data_pagamento: admin.firestore.FieldValue.serverTimestamp(),
          valor: paymentData.transaction_amount,
          metodo: 'Pix',
          pagamento_id: paymentId,
        });

        // Atualizar status no perfil do aluno preservando demais dados
        const studentRef = db.collection('ALUNOS').doc(alunoId);
        batch.update(studentRef, {
          'financeiro.statusPagamento': 'pago',
          'financeiro.ultimaConfirmacao': admin.firestore.FieldValue.serverTimestamp(),
          'financeiro.data_vencimento': admin.firestore.Timestamp.fromDate(new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)),
        });

        await batch.commit();
        console.log(`Pagamento ${paymentId} aprovado e sincronizado para o aluno ${alunoId}`);
      }
    }
  } catch (error) {
    console.error('Erro no processamento do Webhook:', error);
  }
}
