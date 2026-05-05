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

### 🏗️ Arquitetura do Sistema (High-Level)
O Dojo Manager utiliza uma arquitetura baseada em nuvem, integrando o frontend Flutter com os serviços do Firebase e gateways de pagamento externos.

```mermaid
graph TD
    User((Usuário / Aluno)) --> PWA[Flutter PWA / Mobile]
    Admin((Administrador)) --> PWA
    
    subgraph "Google Cloud / Firebase"
        PWA --> Auth[Firebase Auth]
        PWA --> Firestore[(Cloud Firestore)]
        PWA --> Storage[Firebase Storage]
    end
    
    subgraph "Integrações Externas"
        PWA --> MP[Mercado Pago API]
        Firestore -.-> Webhooks[Backend / Webhooks]
        Webhooks --> MP
    end

    style PWA fill:#02569B,stroke:#fff,stroke-width:2px,color:#fff
    style Firestore fill:#FFCA28,stroke:#000,stroke-width:1px
    style Auth fill:#FFCA28,stroke:#000,stroke-width:1px
    style Storage fill:#FFCA28,stroke:#000,stroke-width:1px
```

### 🔐 Fluxo de Autenticação e Segurança (Foco LGPD)
O acesso aos dados é protegido por camadas de autenticação JWT e Regras de Segurança no nível do banco de dados (Firestore Security Rules), garantindo que apenas o dono do dado ou administradores autorizados possam visualizar informações sensíveis.

```mermaid
sequenceDiagram
    participant U as Usuário
    participant P as PWA (Frontend)
    participant A as Firebase Auth
    participant F as Firestore (Security Rules)
    participant D as Dados Sensíveis (PII)

    U->>P: Login (E-mail/Senha)
    P->>A: Autenticar
    A-->>P: Retorna JWT (uid)
    
    U->>P: Solicita Dossiê 360
    P->>F: Query /ALUNOS/{uid}
    
    Note over F: Validação: request.auth.uid == resource.data.uid
    
    alt Autorizado
        F-->>P: Retorna PII (CPF, Endereço, Saúde)
        P-->>U: Exibe Dados Protegidos
    else Não Autorizado (IDOR Prevention)
        F-->>P: Erro 403 (Permission Denied)
        P-->>U: Alerta de Segurança
    end
```

### 📊 Estrutura do Banco de Dados (Entidades)
Relacionamento entre as principais coleções do Firestore, centradas na entidade do Aluno.

```mermaid
erDiagram
    ALUNOS ||--o{ PAGAMENTOS : "possui"
    ALUNOS ||--o{ FREQUENCIA : "registra"
    ALUNOS ||--o{ GRADUACOES : "conquista"
    ALUNOS ||--o| SAUDE_ANAMNESE : "preenche"
    ALUNOS ||--o{ MATRICULAS : "vincula"
    
    ALUNOS {
        string uid PK
        string nome
        string faixa_atual
        map dados_pessoais
        string foto_url
    }
    
    PAGAMENTOS {
        string id PK
        string aluno_id FK
        timestamp data_vencimento
        float valor
        string status
    }
    
    FREQUENCIA {
        string id PK
        string aluno_id FK
        timestamp data_treino
        string modalidade
    }
    
    GRADUACOES {
        string id PK
        string aluno_id FK
        string modalidade
        string faixa
        string grau
    }
```
