import { VercelRequest, VercelResponse } from '@vercel/node';
import admin from 'firebase-admin';

// Initialize Firebase Admin (Environment variables must be set in Vercel)
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
  // 1. Immediate response to Mercado Pago (Required to avoid re-deliveries)
  res.status(200).send('OK');

  if (req.method !== 'POST') return;

  try {
    const { action, data } = req.body;

    // We only care about payment status changes
    if (action === 'payment.created' || action === 'payment.updated') {
      const paymentId = data.id;

      // 2. Fetch ground truth from Mercado Pago API
      const mpResponse = await fetch(`https://api.mercadopago.com/v1/payments/${paymentId}`, {
        headers: {
          'Authorization': `Bearer ${process.env.MP_ACCESS_TOKEN}`,
        },
      });

      if (!mpResponse.ok) {
        console.error(`Failed to fetch payment ${paymentId} from MP API`);
        return;
      }
      
      const paymentData = await mpResponse.json();

      if (paymentData.status === 'approved') {
        const alunoId = paymentData.external_reference;
        if (!alunoId) {
          console.error(`Payment ${paymentId} has no external_reference`);
          return;
        }

        // 3. Idempotency check: Don't process if already approved in Firestore
        const paymentRef = db.collection('PAGAMENTOS').doc(paymentId.toString());
        const doc = await paymentRef.get();

        if (doc.exists && doc.data()?.status === 'approved') {
          console.log(`Payment ${paymentId} was already processed.`);
          return;
        }

        // 4. Atomic Update (Batch)
        const batch = db.batch();
        
        // Log to payment history
        batch.set(paymentRef, {
          aluno_id: alunoId,
          payment_id: paymentId,
          status: 'approved',
          valor: paymentData.transaction_amount,
          data: admin.firestore.FieldValue.serverTimestamp(),
          metodo: 'pix',
        }, { merge: true });

        // Update student's financial status
        // Rules: status -> pago, date -> +30 days
        const studentRef = db.collection('ALUNOS').doc(alunoId);
        
        // Calculate new expiration date
        const nextDueDate = new Date();
        nextDueDate.setDate(nextDueDate.getDate() + 30);

        batch.update(studentRef, {
          'financeiro.statusPagamento': 'pago',
          'financeiro.ultimaConfirmacao': admin.firestore.FieldValue.serverTimestamp(),
          'financeiro.data_vencimento': admin.firestore.Timestamp.fromDate(nextDueDate),
        });

        await batch.commit();
        console.log(`Payment ${paymentId} synced successfully for student ${alunoId}`);
      }
    }
  } catch (error) {
    console.error('Webhook processing error:', error);
  }
}
