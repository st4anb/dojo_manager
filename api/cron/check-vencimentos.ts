import { VercelRequest, VercelResponse } from '@vercel/node';
import admin from 'firebase-admin';
import axios from 'axios';

// Inicialização do Firebase Admin
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

/**
 * Endpoint de Cron para verificação preventiva de faturamento.
 * Deve ser disparado diariamente via Vercel Cron.
 */
export default async function handler(req: VercelRequest, res: VercelResponse) {
  // 1. Verificação de cabeçalho de autorização da Vercel Cron (opcional em dev)
  // const authHeader = req.headers['authorization'];
  // if (authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
  //   return res.status(401).send('Unauthorized');
  // }

  console.log('🤖 Iniciando verificação de vencimentos futuros...');

  try {
    const now = new Date();
    const rangeLimit = new Date();
    rangeLimit.setDate(now.getDate() + 5); // Busca vencimentos nos próximos 5 dias

    // 2. Query: Alunos ativos que vencem nos próximos 5 dias
    const studentsSnapshot = await db.collection('ALUNOS')
      .where('financeiro.proximoVencimento', '<=', admin.firestore.Timestamp.fromDate(rangeLimit))
      .where('role', '==', 'aluno')
      .get();

    if (studentsSnapshot.empty) {
      console.log('✅ Nenhum aluno com vencimento próximo identificado.');
      return res.status(200).send('No actions needed.');
    }

    let processedCount = 0;

    for (const studentDoc of studentsSnapshot.docs) {
      const student = studentDoc.data();
      const uid = studentDoc.id;
      
      // Critério extra: Só gerar para quem está como 'pago' (ciclo normal)
      const statusAtivo = student.financeiro?.statusPagamento?.toLowerCase();
      if (statusAtivo !== 'pago' && statusAtivo !== 'approved') continue;

      // 3. Chave de Idempotência: Mês_Ano_UID para evitar cobranças duplicadas no mesmo ciclo
      const monthPrefix = rangeLimit.getMonth() + 1;
      const yearSuffix = rangeLimit.getFullYear();
      const cycleId = `CY_${monthPrefix}_${yearSuffix}_${uid}`;

      // Verifica se já existe uma cobrança PENDENTE ou APROVADA para este ciclo
      const paymentCheck = await db.collection('PAGAMENTOS')
        .where('ciclo_id', '==', cycleId)
        .limit(1)
        .get();

      if (!paymentCheck.empty) {
        console.log(`ℹ️ Aluno ${student.nome} já possui cobrança para o ciclo ${cycleId}.`);
        continue;
      }

      // 4. Apenas registra a cobrança pendente (O App gerará o link Pix via Vercel)
      try {
        const valorPlano = student.financeiro?.valor_plano || 100;

        const batch = db.batch();
        const newPaymentRef = db.collection('PAGAMENTOS').doc();

        // A) Registra novo pagamento global
        batch.set(newPaymentRef, {
          aluno_id: uid,
          ciclo_id: cycleId,
          valor: valorPlano,
          status: 'pendente',
          created_at: admin.firestore.FieldValue.serverTimestamp(),
          tipo: 'renovacao_automatica'
        });

        // B) Atualiza o perfil do aluno
        batch.update(studentDoc.ref, {
          'financeiro.valorPendente': valorPlano,
          'updated_at': admin.firestore.FieldValue.serverTimestamp()
        });

        await batch.commit();
        processedCount++;
        console.log(`✅ Nova cobrança gerada para: ${student.nome}`);
      } catch (err) {
        console.error(`❌ Erro ao gerar cobrança para ${student.nome}:`, err);
      }
    }

    res.status(200).send(`Processamento finalizado. ${processedCount} cobranças geradas.`);
  } catch (error) {
    console.error('❌ Erro Fatal no Cron de Vencimentos:', error);
    res.status(500).send('Internal Server Error');
  }
}

