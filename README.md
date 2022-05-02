## **Sobre o Asset**

Este asset foi projetado para atuar como plataforma de curadoria de Watson Assistants. A partir dos logs de conversação gerados pelo mesmo, dados a respeito de seu desempenho são extraídos e transformados em informações de alto nível voltados para o público executivo. Como exemplo, temos: quantidade de conversas não atendidas (transferidas para atendente humano ou não), qualidade da compreensão de intenções do cliente por parte do assistente, histórico do volume de conversas diário, desempenho ao longo do tempo entre outros.

## Realizando o Deployment dos Recursos

Essa documentação explica os detalhes do funcinamento do asset. Para visualizar a documentação de Deployment dos recursos [acesse esse guia](https://github.ibm.com/Innovation-Studio-Assets/assistant-curator/tree/master/terraform)

## **Arquitetura**

![img](https://portal-de-demos-imgs.s3.us-south.cloud-object-storage.appdomain.cloud/assistant-curator-arch.png)

O asset está estruturado em duas principais partes:

- Uma sequência de [**cloud functions**](https://cloud.ibm.com/docs/openwhisk) que atua na plataforma da IBM Cloud em intervalos de tempo definidos recebendo, transformando e armazenando os logs do assistente;

- Um frontend em que o curador pode avaliar o entendimento do assistente no nível da conversação e visualizar um [**Dashboard executivo**](https://cloud.ibm.com/docs/cognos-dashboard-embedded?topic=cognos-dashboard-embedded-gettingstartedtutorial) gerado a partir dos dados extraídos.

A sequência de cloud functions se comunica com o assistente através do método [_listLogs()_](https://cloud.ibm.com/apidocs/assistant-v1?code=node#listlogs) da [API v1](https://cloud.ibm.com/apidocs/assistant-v1) do Watson Assistant. Uma vez com todos os logs, a sequência realiza as seguintes tarefas:

1. Retira informações consideradas como as mais relevantes para a tarefa de curadoria no **nível do log**:

   - ID do usuário que com quem o assistente estava conversando;
   - ID da conversa a qual este log pertence;
   - ID do log em questão;
   - A mensagem enviada pelo cliente e a hora que esta foi recebida;
   - A resposta dada pelo assistentee a hora que esta foi entregue;
   - O título do _node_ da árvore de diálogo do assistente acionado nesta transação;
   - As intenções compreendidas pelo assistente nessa transação;
   - A confiança que o assistente tem na intenção que escolheu como principal (valor numérico);
   - As entidades compreendidas pelo assistente nessa transação;

2. Agrupa os logs em conversas de acordo com o _conversationID_ que este carrega e:

   - Classifica se o meio utilizado na conversa foi telefônico ou por troca de mensagens;
   - Dá a data e hora do início da mesma;
   - Salva a duração todal da mesma (em segundos);
   - Salva, se houver, a nota de feedback que o assistente recebeu do cliente;
   - Analisa e salva se a conversa foi ou não transferida para atendente humano;
   - Classifica se a conversa é relevante com base na existência ou não de certas intents em algum dos logs participantes;
   - Indica se esta conversa é o primeiro contato do cliente com o assistente ou não.

3. Para as conversas realizadas através de telefone, armazena dados referentes ao número e IP do usuário e também se houve interrupções de voz por parte do cliente (cliente falando "em cima" do assistente)

4. Para todas as conversas, armazena também as variáveis de ambiente geradas no decorrer da mesma, classificando o seu tipo de dado (Ex.: "string", "object", "boolean", etc.)

5. Manipulados os logs dessa forma, a sequência finaliza inserindo-os em três bases de dados:[ **Cloudant**](https://cloud.ibm.com/docs/Cloudant?topic=Cloudant-client-libraries#client-libraries), [**COS (Cloud Object Storage)**](https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-getting-started-cloud-object-storage) e [**Db2**](https://cloud.ibm.com/docs/Db2onCloud?topic=Db2onCloud-getting-started)

Através de conexão do [**Db2**](https://cloud.ibm.com/docs/Db2onCloud?topic=Db2onCloud-getting-started), com o [**Cognos**](https://cloud.ibm.com/docs/cognos-dashboard-embedded?topic=cognos-dashboard-embedded-gettingstartedtutorial), gráficos são construídos a partir das informações nele armazenadas, geradas pelas cloud functions.

Estes gráficos serão consumidos no frontend, que também conta com uma tabela para que o curador possa avaliar o entendimento do assitente. Essa nota - de padrão variando de 1 a 5 - é utilizada para fazer a validação da qualidade da construção e treino do assistente, uma vez que, ao cruzar a confiança que o assistente tem na principal intenção que compreendeu na frase do cliente com a nota atribuída pelo curador nesta mesma frase, é possível validar a **Eficiência** x **Eficácia** do assistente.

Entenda-se eficiência como "o fornecer ampla cobertura para as perguntas" e eficácia como "o ato de fornecer respostas certas".

## **Pre-requisitos**

Para continuar com esta documentação, é necessário possuir uma conta na [**IBM Cloud**](https://cloud.ibm.com/).

Também é necessário uma instância do Watson Assistant, com um assistente deployado e alguns logs de conversas com o mesmo disponíveis (de padrão, os logs de assistentes dos planos Lite e Plus ficam armazenados apenas por 30 dias).

São necessárias intâncias do [**Cloudant**](https://cloud.ibm.com/docs/Cloudant?topic=Cloudant-ibm-cloud-public), [**COS**](https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-getting-started-cloud-object-storage) e [**Db2**](https://cloud.ibm.com/docs/Db2onCloud?topic=Db2onCloud-getting-started). Recomenda-se a realização do deploy de todas elas na própria IBM Cloud.

Para a realização da extração de sentimento das mensagens enviadas pelo cliente, também é necessário instanciar o serviço do [**NLU**](https://cloud.ibm.com/docs/natural-language-understanding?topic=natural-language-understanding-getting-started).

O último serviço a ser instanciado na IBM Cloud é o [**Cognos Embedded**](https://cloud.ibm.com/docs/cognos-dashboard-embedded?topic=cognos-dashboard-embedded-gettingstartedtutorial), responsável pelos Dashboards a ser construídos e apresentados no front.

Conhecimento de como fazer upload de código como [**cloud function**](https://cloud.ibm.com/docs/openwhisk) na IBM Cloud é recomendado, mas este processo acontecerá de forma automatizada através de um script do [**terraform**](https://www.terraform.io/docs).

Por último, por gentileza certifique-se de que [**Docker**](https://docs.docker.com/get-docker/) está instalado em sua máquina, uma vez que precisaremos do mesmo para carregar alguns containers e arquivos.

## **Componentes**

Conforme acima, este asset é composto por duas principais partes:

### **Sequência de cloud functions**

Composta de 5 funções diferentes, a sequência está organizada de forma que o output da primeira seja o input da seguinte e por aí em diante. São elas:

- **create-tables-cf**

  Cria, se necessário, as quatro tabelas que receberam os logs processados na instância do Db2 especificada.

- **process-logs-cf**

  Realiza a extração de informações no nível do log (Etapa 1 descrita no tópico de arquitetura)

- **process-conversations-cf**

  Agrupa os logs no nível da conversa e extraí informações no nível da conversa (Etapas 2 e 3)

- **enrich-cf**

  Consulta o [**NLU**](https://cloud.ibm.com/docs/natural-language-understanding?topic=natural-language-understanding-getting-started) para extrair o sentimento do texto, armazenado sob forma numérica variando entre **-1**, para sentimentos negativos, e **+1**, para sentimentos positivos. Além disso, nesta função é realizada a extração das variáveis de contexto das conversas (Etapa 4)

- **insert-logs-cf**

  A partir dos objetos gerados nas funções anteriores, nesta etapa final é realizada a comunicação com as três bases de dados: [**Cloudant**](https://cloud.ibm.com/docs/Cloudant?topic=Cloudant-ibm-cloud-public), [**COS**](https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-getting-started-cloud-object-storage) e [**Db2**](https://cloud.ibm.com/docs/Db2onCloud?topic=Db2onCloud-getting-started). No Cloudant e COS são armazenados os logs a fim de manter backup dos mesmos, no Db2 temos o armazenamento das informações relevantes filtradas e geradas pelas funções.

### **Interface do curador**

A interface do curador tem duas principais funcionalidades:

- Apresentar a conversa entre cliente e assistente no nível da troca de mensagens para avaliação humana de sua assertividade através de atribuição de nota (1 - 5);

- Disponibilizar uma interface para a construção e consulta de dashboards interativos que apresentem o desempenho do assistente no decorrer do tempo.

A interface do curador se comunica com a instância do Db2 através do [**ibm_db**](https://www.npmjs.com/package/ibm_db), pacote para Node que funciona como API da instância de Db2 selecionada.

Recebidos esses dados, temos a apresentação dos logs, organizados em conversas, sob a forma de tabela:

![img](https://portal-de-demos-imgs.s3.us-south.cloud-object-storage.appdomain.cloud/assistant-curator01.png)

Há também uma aba dedicada para a busca de mensagens a partir das Intenções identificadas nas mesmas, que apresenta todas as intents identificadas e uma barra de pesquisa para filtrar o resultado:

![img](https://portal-de-demos-imgs.s3.us-south.cloud-object-storage.appdomain.cloud/assistant-curator02.png)

A comunicação com o a instância do Cognos Embedded também se dá através de sua API, cuja documentação está disponível nos seguintes links: [**CognosApi Docs**](https://dde-us-south.analytics.ibm.com/daas/jsdoc/cognos/api/CognosApi.html), [**CognosApi File**](https://dde-us-south.analytics.ibm.com/daas/CognosApi.js).

Uma vez que a conexão é realizada, uma sessão do Cognos é inicializada para o usuário, que passa a visualizar a interface de dashboards disponível na aba "Cognos" do frontend:

![img](https://portal-de-demos-imgs.s3.us-south.cloud-object-storage.appdomain.cloud/assistant-curator04.png)

Os dashboards, uma vez abertos e/ou alterados podem ser salvos no [**Cloudant**](https://cloud.ibm.com/docs/Cloudant?topic=Cloudant-ibm-cloud-public), de forma que ficam disponíveis entre acessos.

## **Como realizar o Deployment**

Para a documentação sobre como realizar o deploy deste asset, por gentileza consulte o seguinte guia do passo-a-passo para automaticamente instanciar todos os serviços necessários: [**terraform**](https://github.ibm.com/Innovation-Studio-Assets/assistant-curator/tree/master/terraform).

## **Guia do Usuário**

Conforme mencionado nos tópicos anteriores, a interface do curador é conectada a três serviços:

- [**Db2**](https://cloud.ibm.com/docs/Db2onCloud?topic=Db2onCloud-getting-started), com suas 4 tabelas preenchidas através da execução das cloud functions;

- [**Cognos Embedded**](https://cloud.ibm.com/docs/cognos-dashboard-embedded?topic=cognos-dashboard-embedded-gettingstartedtutorial), para confecção e exibição dos dashboards;

- [**Cloudant**](https://cloud.ibm.com/docs/Cloudant?topic=Cloudant-client-libraries#client-libraries), para salvar as alterações realizadas nas dashboards.

Para conexão com suas respectivas instâncias, as credenciais referentes a cada uma delas devem ser informadas pelo usuário através da interface do curador. Existem dois módulos de configurações a ser preenchidos:

O primeiro modal de configurações é referente a conexão com o **Db2** para coleta de dados de sua tabela de logs. Ele é apresentado através de clique no ícone de engrenagem localizado no canto superior direito do header caso o usuário se encontre na **aba inicial** ou na **aba de busca de intenções**:

![img](https://portal-de-demos-imgs.s3.us-south.cloud-object-storage.appdomain.cloud/assistant-curator03.png)

Para preenchê-lo são necessárias as seguintes credenciais:

- **Connection String** de sua instância do Db2:

  Embora todos os dados necessários para compor esta informação se encontrem nas credenciais de serviço disponíveis na página inicial da instância do **Db2** na **IBM Cloud**, eles não estão formatados corretamente. A **Connection String** deve ser composta nesta sintaxe:

      DATABASE=<nome de sua database>;HOSTNAME=<seu hostname>;PORT=<port de sua instância>;PROTOCOL=TCPIP;UID=<seu usuário de acesso>;PWD=<sua senha de acesso>;Security=SSL;

- **Nome da tabela de Logs**

  De padrão, o nome da tabela está configurado como "**logs**"

O segundo modal de configurações diz respeito aos dados necessários para conexão com o **Cognos**, com o **Db2 através do Cognos** e com o **Cloudant**, a fim de (respectivamente) **apresentar**, **popular** e **salvar** as dashboards. Ele é apresentado através de clique no mesmo ícone de engrenagem, uma vez que o usuário esteja na **aba Cognos**:

![img](https://portal-de-demos-imgs.s3.us-south.cloud-object-storage.appdomain.cloud/assistant-curator05.png)

Para preenchê-lo são necessárias as seguintes credenciais:

- **Cognos**

  - Usuário de acesso ao Cognos
  - Senha de acesso ao Cognos

    Ambos dados disponíveis nas "credenciais de serviço" da página inicial de sua instância na IBM Cloud, embora com nomes diferentes: O nome de usuário está definido como "**client_id**" e a senha como "**client_secret**".

- **Cloudant**

  - Nome da database a ser consultada

    Pode-se definir o nome desejado, embora, de padrão, espera-se por "**dashboards**".

  - URL de sua instância do Cloudant
  - apiKey de acesso ao Cloudant

    Ambos dados disponíveis nas "credenciais de serviço" da página inicial de sua instância na IBM Cloud.

- **Db2**

  - Link do módulo.xsd

    Conforme explicado na documentação de "trabalhando com fonte de dados" disponível neste [**link**](https://cloud.ibm.com/docs/cognos-dashboard-embedded?topic=cognos-dashboard-embedded-workingwithdatasources).

  - URL de conexão através do padrão JDBC

    Este dado se encontra nas aba de "credenciais do serviço" da página inicial da instância, embora precise ser formatado. Sua sintaxe deve ser conforme o seguinte exemplo:

        jdbc:db2://<seu hostname>:<sua PORT>/<nome de sua database>:sslConnection=true;

  - Classe do driver JDBC

    Igualmente explicado na documentação de "trabalhando com fonte de dados" disponível neste [**link**](https://cloud.ibm.com/docs/cognos-dashboard-embedded?topic=cognos-dashboard-embedded-workingwithdatasources).

  - Schema em que estão salvas as tabelas no Db2

    De padrão, o schema da Db2 é o nome de seu usuário em letras maiúsculas, a não ser que seja especificado o contrário.

  - Usuário de acesso ao Db2
  - Senha de acesso ao Db2

    Ambos dados disponíveis nas "credenciais de serviço" da página inicial de sua instância na IBM Cloud.

- **Nome das Tabelas**

  Nesta aba são esperados os nomes das quatro tabelas salvas no Db2. De padrão, são elas, respectivamente:

  - **Logs**
  - **Conversations**
  - **Calls**
  - **ContextVariables**

Uma vez que as credenciais sejam preenchidas, uma primeira vez, não é necessário refazê-lo nos demais acessos, salvo exceções.

Na aba "**Cognos**" tem-se a interface do Dashboard interativo que pode ser salvo no Cloudant para que, no acesso seguinte, suas alterações sejam carregadas da base de dados.

Para fazê-lo, basta clicar no ícone do disquete que abrirá duas opções: **Salvar** ou **Buscar** um dashboard:

![img](https://portal-de-demos-imgs.s3.us-south.cloud-object-storage.appdomain.cloud/assistant-curator06.png)

![img](https://portal-de-demos-imgs.s3.us-south.cloud-object-storage.appdomain.cloud/assistant-curator07.png)

O nome inserido para salvá-lo será configurado como padrão, de forma que a próxima vez que a aba Cognos for acessada, este será o dashboard inicialmente exibido.

Caso outro dashboard seja carregado através da opção **Buscar**, este novo será escolhido como padrão, sem que o salvo anteriormente seja excluído.

No caso de não haver nenhum dashboard salvo no **Cloudant** consultado, um dashboard padrão com visualizações já disponíveis a respeito do assistente consultado será inicializado e apresentado.
