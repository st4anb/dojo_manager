import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import axios from "axios";
import * as PDFDocument from "pdfkit";
import * as cors from "cors";

const corsHandler = cors({ origin: true });

admin.initializeApp();

/**
 * Webhook para processamento de notificações de pagamento do Mercado Pago.
 * Automatiza a atualização do status financeiro e ciclo de isenção de 30 meses.
 */
export const mercadoPagoWebhook = functions.https.onRequest(async (req, res) => {
  // 1. Filtro básico de segurança e tipo de requisição
  if (req.method !== "POST") {
    res.status(405).send("Method Not Allowed");
    return;
  }

  const payload = req.body;
  const paymentId = (payload.data && payload.data.id) || (payload.resource && payload.resource.split("/").pop());
  const topic = payload.type || payload.action || req.query.topic;

  // Apenas processamos se o tópico for 'payment'
  if (topic === "payment" || topic === "payment.created" || topic === "payment.updated") {
    try {
      // Nota: O Access Token deve ser configurado via Firebase Secrets:
      // firebase functions:secrets:set MP_ACCESS_TOKEN
      const mpAccessToken = process.env.MP_ACCESS_TOKEN;

      if (!mpAccessToken) {
        console.error("Erro: MP_ACCESS_TOKEN não configurado no Secrets Manager.");
        res.status(500).send("Configuration Error");
        return;
      }

      // 2. Consultar detalhes do pagamento na API oficial
      const response = await axios.get(`https://api.mercadopago.com/v1/payments/${paymentId}`, {
        headers: {
          "Authorization": `Bearer ${mpAccessToken}`,
        },
      });

      const paymentData = response.data;

      // 3. Validar Status Approved e extrair Aluno UID (external_reference)
      if (paymentData.status === "approved") {
        const uid = paymentData.external_reference;

        if (uid) {
          const agora = new Date();
          // Cálculo de 30 meses de isenção (conforme Diretriz 3)
          const vencimentoIsencaoDate = new Date(agora.getFullYear(), agora.getMonth() + 30, agora.getDate());

          await admin.firestore().collection("alunos").doc(uid).set({
            status_pagamento: "pago",
            financeiro: {
              statusPagamento: "pago",
              dataPagamento: admin.firestore.FieldValue.serverTimestamp(),
              vencimentoIsencao: admin.firestore.Timestamp.fromDate(vencimentoIsencaoDate),
              idUltimoPagamento: paymentId,
            },
          }, { merge: true });

          console.log(`Webhook Sucesso: Aluno ${uid} recebeu isenção de 30 meses.`);
        } else {
          console.warn(`Aviso: Pagamento ${paymentId} aprovado mas sem external_reference.`);
        }
      } else {
        console.log(`Webhook Info: Pagamento ${paymentId} com status '${paymentData.status}'. Nenhuma ação tomada.`);
      }
    } catch (error) {
      console.error(`Erro Crítico no Webhook (Payment ID: ${paymentId}):`, error);
      // Mesmo em erro de processamento interno, retornamos 200 para evitar loop de retentativas do MP
      // unless it's a transient error you definitely want MP to retry.
    }
  }

  // Resposta imediata 200 OK (Diretriz 3)
  res.status(200).send("OK");
});

/**
 * Gera um Dossiê Completo do Aluno em PDF (Raio-X).
 * Agrega dados de perfil, frequência, KI e histórico financeiro.
 */
export const gerarRelatorioPDF = functions.https.onRequest(async (req, res) => {
  return corsHandler(req, res, async () => {
    try {
      const { id } = req.query;

      if (!id) {
        res.status(400).send("ID do aluno é obrigatório.");
        return;
      }

      // 1. Coleta de Dados
      const aluDoc = await admin.firestore().collection("alunos").doc(id.toString()).get();
      if (!aluDoc.exists) {
        res.status(404).send("Aluno não encontrado.");
        return;
      }

      const aluData = aluDoc.data()!;
      const personal = aluData.dados_pessoais || {};
      const financeiro = aluData.financeiro || {};

      // Frequência
      const freqSnap = await admin.firestore().collection("frequencia")
        .where("aluno_id", "==", id)
        .where("status", "==", "aprovado")
        .get();
      const totalCheckins = freqSnap.size;

      // Config (para metas)
      const configSnap = await admin.firestore().collection("config").doc("geral").get();
      const config = configSnap.data() || {};
      
      // 2. Criação do PDF
      const doc = new PDFDocument({ margin: 50, size: "A4" });
      const filename = `Dossie_${personal.nome?.replace(/\s+/g, "_") || "Aluno"}.pdf`;

      res.setHeader("Content-Type", "application/pdf");
      res.setHeader("Content-Disposition", `attachment; filename=${filename}`);

      doc.pipe(res);

      // --- CABEÇALHO ---
      doc.fillColor("#000000").fontSize(20).text("DOJO MANAGER - DOSSIÊ DO ALUNO", { align: "center" });
      doc.moveDown();
      doc.fontSize(10).fillColor("#666666").text(`Relatório gerado em: ${new Date().toLocaleString("pt-BR")}`, { align: "right" });
      doc.moveDown();

      doc.strokeColor("#FFD700").lineWidth(2).moveTo(50, doc.y).lineTo(545, doc.y).stroke();
      doc.moveDown();

      // --- DADOS PESSOAIS ---
      doc.fillColor("#000000").fontSize(14).text("DADOS DO ATLETA", { underline: true });
      doc.moveDown(0.5);
      doc.fontSize(11).fillColor("#333333");
      doc.text(`Nome: ${personal.nome || "---"}`);
      doc.text(`Idade: ${personal.idade || "---"}`);
      doc.text(`Modalidade(s): ${Array.isArray(aluData.modalidade) ? aluData.modalidade.join(", ") : aluData.modalidade || "---"}`);
      doc.text(`Faixa: ${personal.faixa || "BRANCA"}`);
      doc.text(`Data de Matrícula: ${personal.data_matricula || "---"}`);
      doc.moveDown();

      // --- PERFORMANCE & GAMIFICAÇÃO ---
      doc.fontSize(14).fillColor("#000000").text("PERFORMANCE & GAMIFICAÇÃO 🥋", { underline: true });
      doc.moveDown(0.5);
      doc.fontSize(11);
      doc.text(`Total de Check-ins (Físico): ${totalCheckins}`);
      doc.text(`Saldo de KI (Teórico): ${aluData.ki_total || 0} pontos`);
      
      const patches = aluData.patchesPorModalidade || {};
      const patchList = Object.keys(patches).join(", ");
      doc.text(`Insígnias (Patches): ${patchList || "Nenhuma conquistada até o momento."}`);
      doc.moveDown();

      // --- EXTRATO FINANCEIRO ---
      doc.fontSize(14).fillColor("#000000").text("HISTÓRICO FINANCEIRO 💰", { underline: true });
      doc.moveDown(0.5);

      // Simulação de tabela (Cabeçalho da Tabela)
      const tableTop = doc.y;
      doc.fontSize(10).fillColor("#000000").font("Helvetica-Bold");
      doc.text("Referência", 50, tableTop);
      doc.text("Status", 150, tableTop);
      doc.text("Valor", 250, tableTop);
      doc.text("Data Pagto", 350, tableTop);
      
      doc.moveTo(50, tableTop + 15).lineTo(545, tableTop + 15).stroke();
      doc.font("Helvetica").fontSize(10).fillColor("#333333");

      let rowY = tableTop + 25;
      
      // Aqui idealmente iteraríamos sobre uma subcoleção de faturas, 
      // mas como temos apenas o status atual no modelo, mostraremos o histórico recente simulado ou o status atual.
      const mesAtual = new Date().toLocaleString("pt-BR", { month: "long", year: "numeric" });
      doc.text(mesAtual, 50, rowY);
      doc.text((financeiro.status || "PENDENTE").toUpperCase(), 150, rowY);
      doc.text(`R$ ${aluData.valor_mensalidade || config.valor_base_mensalidade || "0,00"}`, 250, rowY);
      doc.text(financeiro.data_pagamento ? new Date(financeiro.data_pagamento.seconds * 1000).toLocaleDateString("pt-BR") : "---", 350, rowY);

      doc.moveDown(5);

      // --- RODAPÉ ---
      doc.fontSize(8).fillColor("#999999").text("Relatório oficial gerado pelo sistema Dojo Manager V16 Force Sync.", { align: "center", baseline: "bottom" });
      doc.text("As informações aqui contidas são para uso interno e administrativo.", { align: "center", baseline: "bottom" });

      doc.end();

    } catch (error) {
      console.error("Erro ao gerar PDF:", error);
      res.status(500).send("Erro interno ao gerar relatório.");
    }
  });
});
