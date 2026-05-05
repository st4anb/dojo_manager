const admin = require('firebase-admin');
const { MercadoPagoConfig, Preference } = require('mercadopago');
const crypto = require('crypto');
const { applySecurityHeaders, applyCors } = require('../_middleware');

// Inicialização robusta do Firebase Admin
if (!admin.apps.length) {
    try {
        if (process.env.FIREBASE_SERVICE_ACCOUNT) {
            const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
            admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
        } else {
            // Fallback para variáveis individuais se a Service Account não estiver configurada como JSON
            admin.initializeApp({
                credential: admin.credential.cert({
                    projectId: process.env.FIREBASE_PROJECT_ID,
                    clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
                    privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
                }),
            });
        }
    } catch (e) {
        console.error("Erro ao inicializar Firebase Admin:", e);
    }
}

const db = admin.firestore();
const client = new MercadoPagoConfig({ accessToken: process.env.MP_ACCESS_TOKEN });

module.exports = async (req, res) => {
    applySecurityHeaders(res);
    applyCors(req, res);
    
    if (req.method === 'OPTIONS') return res.status(204).end();
    if (req.method !== 'POST') return res.status(405).json({ error: 'Método não permitido' });

    try {
        // LOG CRÍTICO PARA DEBUG: Veja o que está chegando do Flutter
        console.log("PAYLOAD RECEBIDO DO FLUTTER:", req.body);

        // Suporte para body tanto em string quanto em objeto
        const body = typeof req.body === 'string' ? JSON.parse(req.body) : req.body;
        const valor = Number(body?.valor);
        const aluno_id = body?.aluno_id;

        if (!valor || isNaN(valor) || !aluno_id) {
            console.error("Erro de Validação: valor ou aluno_id inválidos.");
            return res.status(400).json({ 
                error: 'Dados inválidos. Envie valor (número) e aluno_id (string).',
                received: { valor, aluno_id }
            });
        }

        const order_nsu = crypto.randomUUID ? crypto.randomUUID() : require('uuid').v4();
        const preference = new Preference(client);

        const response = await preference.create({
            body: {
                items: [{
                    id: order_nsu,
                    title: 'Mensalidade - CT Pandora',
                    unit_price: valor,
                    quantity: 1,
                    currency_id: 'BRL'
                }],
                back_urls: {
                    success: 'https://dojo-manager-2bf1a.web.app/#/evolution',
                    failure: 'https://dojo-manager-2bf1a.web.app/#/evolution',
                    pending: 'https://dojo-manager-2bf1a.web.app/#/evolution'
                },
                auto_return: 'approved',
                external_reference: order_nsu,
                notification_url: 'https://backend-vercel-theta-rouge.vercel.app/api/webhooks/mercadopago',
            }
        });

        // Salva na coleção global e no histórico do aluno para manter compatibilidade
        const paymentData = {
            order_nsu, 
            aluno_id, 
            valor, 
            status: 'Pendente', 
            criadoEm: admin.firestore.FieldValue.serverTimestamp(),
            init_point: response.init_point
        };

        const batch = db.batch();
        batch.set(db.collection('PAGAMENTOS').doc(order_nsu), paymentData);
        batch.set(db.collection('ALUNOS').doc(aluno_id).collection('historico_pagamentos').doc(order_nsu), {
            ...paymentData,
            titulo: 'Mensalidade Gerada',
            tipo: 'mensalidade'
        });

        await batch.commit();

        console.log("SUCESSO! Link gerado:", response.init_point);
        return res.status(200).json({ url: response.init_point, order_nsu });

    } catch (error) {
        console.error('ERRO FATAL MERCADO PAGO:', error);
        return res.status(500).json({ error: 'Erro no Mercado Pago', detalhes: error.message });
    }
};
