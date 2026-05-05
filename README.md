# Dojo Manager

**Projeto PWA (Flutter/Dart) para gerenciamento completo de dojo (cadastro, financeiro e progresso).**

O **Dojo Manager** é uma aplicação moderna projetada para simplificar e automatizar as operações diárias de um dojo, oferecendo uma interface elegante e responsiva. Ele abrange desde a gestão de alunos e seus dossiês completos até o controle financeiro detalhado e o acompanhamento de progresso nas modalidades de artes marciais.

---

## 🔒 Arquitetura e Segurança

A segurança e a proteção de dados são os pilares fundamentais da arquitetura do Dojo Manager. O sistema foi construído desde o seu alicerce utilizando as melhores práticas do setor:

*   **Privacy by Design & Conformidade LGPD:** Garantimos a proteção de Dados Pessoais Identificáveis (PII). O sistema opera sob o princípio da minimização, garantindo que os dados armazenados sejam apenas aqueles estritamente necessários para o funcionamento. Dados sensíveis de saúde, financeiros e de contato são blindados contra exposição.
*   **Gestão Segura de Segredos:** Nossa arquitetura implementa **Zero Vazamentos**. Todas as chaves de API, strings de conexão e credenciais são isoladas em variáveis de ambiente ou Key Vaults. O código-fonte é higienizado de ponta a ponta: *nenhuma credencial existe em formato hardcode*.
*   **Controle Rigoroso de Acesso:** Proteção completa contra acessos não autorizados e ataques de referência direta a objetos (IDOR).
*   **Mascaramento em Logs:** Prevenção de vazamento acidental em depuração. Os logs do sistema não expõem PII.

---

## 🚀 Instruções de Instalação

Para configurar o ambiente de desenvolvimento local e rodar o Dojo Manager:

1.  **Clone o Repositório:**
    ```bash
    git clone https://github.com/st4anb/dojo_manager.git
    cd dojo_manager
    ```

2.  **Configuração de Variáveis de Ambiente:**
    *   Crie uma cópia do arquivo de exemplo para configurar suas variáveis.
    *   ```bash
        cp .env.example .env
        ```
    *   Edite o arquivo `.env` inserindo as credenciais corretas do Firebase e do Mercado Pago.
    *   *Lembrete de Segurança:* O arquivo `.env` jamais deve ser comitado. Nosso `.gitignore` já está configurado para blindá-lo.

3.  **Instalação das Dependências:**
    ```bash
    flutter pub get
    ```

4.  **Rodar a Aplicação (Ambiente Local):**
    *   Execute o PWA no Chrome ou Edge:
        ```bash
        flutter run -d chrome
        ```

---

## 🗺️ Metodologia e Fluxogramas

*(Este espaço está reservado para a documentação visual, diagramas arquiteturais e mapas de processos do dojo, que serão adicionados futuramente para ilustrar os fluxos de estado e regras de negócio da aplicação).*
