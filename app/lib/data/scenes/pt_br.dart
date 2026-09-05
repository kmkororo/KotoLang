/// Português (Brasil): tema, situação, tradução da fala, as três opções de ①
/// e a tradução e o motivo de cada resposta de ②. A correta vem primeiro.
library;

const Map<String, Map<String, dynamic>> ptBr = {
  'builtin_w1': {
    'topic': 'Recusar um pedido',
    'setting': 'Um colega pede que você faça a apresentação dele na sexta',
    'ex': [
      {
        'line': 'Você está livre na sexta à tarde? Tenho duas reuniões no mesmo horário. Pode fazer a apresentação para o cliente às três por mim?',
        'gist': [
          'Ele quer que você faça a apresentação na sexta às três',
          'Ele quer que você o acompanhe numa reunião na sexta às três',
          'Ele está dizendo que você pode folgar na sexta à tarde',
        ],
        'native': [
          'Sexta às três é difícil pra mim, meu relatório vence nessa hora. Podemos pedir ao cliente para passar pra segunda?',
          'Claro, eu sento do seu lado e faço anotações.',
          'Obrigado! Então vou folgar na sexta à tarde.',
        ],
        'why': [
          'Recebe o pedido como pedido e propõe uma alternativa',
          'Ouviu "faça por mim" como "venha comigo"',
          'Ouviu um pedido como permissão para folgar',
        ],
      },
      {
        'line': 'Segunda é tarde demais, o cliente vai embora no sábado. Você poderia fazer só os primeiros dez minutos? Depois eu entro por telefone.',
        'gist': [
          'Só os primeiros dez minutos; depois ele entra por telefone',
          'A apresentação inteira; ele não pode estar lá',
          'Passou pra segunda e começa dez minutos mais cedo',
        ],
        'native': [
          'Tá, dez minutos eu consigo. Me manda os primeiros slides e liga às três e dez.',
          'A apresentação inteira? Desculpa, isso eu não consigo.',
          'Segunda serve. Vamos começar dez minutos antes.',
        ],
        'why': [
          'Recebe "dez minutos, depois por telefone" como foi dito',
          'Ouviu "os primeiros dez minutos" como "a apresentação inteira"',
          'Não ouviu "segunda é tarde demais"',
        ],
      },
    ],
  },
  'builtin_w2': {
    'topic': 'Mudar uma reunião',
    'setting': 'Seu chefe pergunta sobre mudar a reunião da semana que vem',
    'ex': [
      {
        'line': 'Podemos mudar a reunião de equipe da semana que vem? Quinta não dá mais pra mim. Que tal sexta de manhã, às nove?',
        'gist': [
          'Mudar a reunião de quinta para sexta às nove',
          'Mudar a reunião de sexta para quinta às nove',
          'Cancelar a reunião da semana que vem',
        ],
        'native': [
          'Sexta às nove funciona pra mim. Aviso os outros.',
          'Quinta às nove está bom pra mim.',
          'Sem reunião semana que vem? Por mim, tudo bem.',
        ],
        'why': [
          'Recebe "para sexta às nove" como foi dito',
          'Trocou quinta por sexta',
          'Ouviu "mudar" como "cancelar"',
        ],
      },
      {
        'line': 'Ótimo. Mais uma coisa: você pode reservar a sala pequena? A grande está ocupada na sexta.',
        'gist': [
          'Reservar a sala pequena; a grande está ocupada na sexta',
          'Reservar a sala grande; a pequena está ocupada',
          'Ele mesmo reserva a sala; nada a fazer',
        ],
        'native': [
          'Claro, reservo a sala pequena para sexta às nove.',
          'Tá, reservo a sala grande.',
          'Ótimo, então você reserva a sala. Obrigado!',
        ],
        'why': [
          'Recebe "você reserva a pequena" como foi dito',
          'Trocou grande por pequena',
          'Ouviu um pedido como algo que a outra pessoa vai fazer',
        ],
      },
    ],
  },
  'builtin_w3': {
    'topic': 'Assumir um erro',
    'setting': 'Seu chefe, sobre uma lista de preços que você enviou a um cliente',
    'ex': [
      {
        'line': 'Recebi um e-mail do cliente. Eles dizem que a lista de preços está com os números errados. Que arquivo você mandou?',
        'gist': [
          'O cliente diz que os números estão errados; que arquivo você mandou?',
          'O cliente diz que a lista não chegou',
          'O cliente gostou da lista',
        ],
        'native': [
          'Desculpe, acho que mandei o arquivo antigo. Vou conferir agora e enviar o certo.',
          'Não receberam? Mando de novo agora.',
          'Obrigado! Que bom que gostaram.',
        ],
        'why': [
          'Responde ao erro e à pergunta sobre o arquivo',
          'Ouviu "números errados" como "não chegou"',
          'Ouviu uma reclamação como elogio',
        ],
      },
      {
        'line': 'Não mande nada ainda. Corrija o arquivo, me mostre primeiro, e depois enviamos juntos.',
        'gist': [
          'Não mandar nada ainda; corrigir, mostrar primeiro, enviar juntos',
          'Reenviar agora; avisar depois',
          'Ele mesmo corrige e envia',
        ],
        'native': [
          'Entendido. Corrijo e mostro pra você antes de sair qualquer coisa.',
          'Tá, estou mandando o arquivo novo agora.',
          'Obrigado por corrigir pra mim.',
        ],
        'why': [
          'Recebe "ainda não, me mostre primeiro" como foi dito',
          'Não ouviu "não mande nada ainda"',
          'Ouviu "você corrige" como "eu corrijo"',
        ],
      },
    ],
  },
  'builtin_w4': {
    'topic': 'Pedem para você ficar até mais tarde',
    'setting': 'Pouco antes do fim do expediente, um colega',
    'ex': [
      {
        'line': 'Desculpa pedir, mas você poderia ficar uma hora a mais hoje? O cliente adiantou o prazo para amanhã de manhã.',
        'gist': [
          'Ficar uma hora a mais hoje; o prazo passou para amanhã de manhã',
          'Chegar uma hora mais cedo amanhã; o prazo é amanhã à tarde',
          'Sair mais cedo hoje; o prazo passou para semana que vem',
        ],
        'native': [
          'Uma hora tudo bem. Por onde começo?',
          'Claro, chego mais cedo amanhã. Que horas?',
          'Ótimo, obrigado! Até amanhã então.',
        ],
        'why': [
          'Recebe "uma hora hoje" e começa a agir',
          'Ouviu "ficar hoje" como "chegar cedo amanhã"',
          'Ouviu "ficar" como "pode ir"',
        ],
      },
      {
        'line': 'Obrigado. Você pode conferir os números do relatório enquanto eu termino os slides? Só os totais da última página.',
        'gist': [
          'Conferir os totais da última página do relatório',
          'Terminar os slides; ele faz o relatório',
          'Ler o relatório inteiro, do começo ao fim',
        ],
        'native': [
          'Beleza, só os totais da última página. Aviso se algo parecer errado.',
          'Tá, termino os slides. Me manda o que você tem.',
          'O relatório inteiro? Isso leva mais de uma hora.',
        ],
        'why': [
          'Recebe "só os totais" como foi dito',
          'Trocou as duas tarefas',
          'Ouviu "só os totais" como "o relatório inteiro"',
        ],
      },
    ],
  },
  'builtin_w5': {
    'topic': 'Receber feedback',
    'setting': 'Seu chefe, sobre um relatório que você entregou',
    'ex': [
      {
        'line': 'Seu relatório estava bom, mas longo demais. Ninguém leu a última página, e era lá que estava o seu ponto principal.',
        'gist': [
          'Estava longo demais; o ponto principal ficou na última página e ninguém leu',
          'Estava curto demais; faltou o ponto principal',
          'Estava bom, principalmente a última página',
        ],
        'native': [
          'Entendi. Vou colocar o ponto principal na primeira página e encurtar.',
          'Vou acrescentar mais páginas com mais detalhes.',
          'Obrigado! Me esforcei muito na última página.',
        ],
        'why': [
          'Recebe "longo demais, o principal no fim" como foi dito',
          'Ouviu "longo demais" como "curto demais"',
          'Ouviu "ninguém leu" como "estava bom"',
        ],
      },
      {
        'line': 'Bom. E para os gerentes, faça uma versão de uma página. Eles só têm cinco minutos para ler.',
        'gist': [
          'Uma versão de uma página para os gerentes; eles têm cinco minutos',
          'Uma versão de cinco páginas para os gerentes; eles têm tempo de sobra',
          'Os gerentes não precisam de nada',
        ],
        'native': [
          'Uma página para os gerentes, entendido. Mando amanhã.',
          'Cinco páginas para os gerentes? Tá, escrevo mais.',
          'Então os gerentes não precisam de cópia. Entendido.',
        ],
        'why': [
          'Recebe "uma página" como foi dito',
          'Ouviu "uma página, cinco minutos" como "cinco páginas"',
          'Não ouviu "faça uma versão"',
        ],
      },
    ],
  },
  'builtin_t1': {
    'topic': 'A gorjeta',
    'setting': 'A conta chega depois do jantar num restaurante',
    'ex': [
      {
        'line': 'Aqui está a conta. Só para avisar, a gorjeta não está incluída. A maioria deixa uns 18 por cento.',
        'gist': [
          'A gorjeta não está incluída; o comum é uns 18%',
          'A gorjeta está incluída; não precisa acrescentar',
          'Neste restaurante não se dá gorjeta',
        ],
        'native': [
          'Tá, obrigado. Vou acrescentar 18 por cento.',
          'Ah, está incluída? Então pago só isso.',
          'Sem gorjeta aqui? Ótimo, obrigado.',
        ],
        'why': [
          'Recebe "não incluída, 18%" como foi dito',
          'Ouviu "não incluída" como "incluída"',
          'Ouviu "deixar gorjeta" como "sem gorjeta"',
        ],
      },
      {
        'line': 'Você pode acrescentar na maquininha. Ela vai pedir para escolher uma porcentagem.',
        'gist': [
          'Acrescenta-se na maquininha escolhendo uma porcentagem',
          'Deixa-se em dinheiro na mesa',
          'Entrega-se na mão do garçom',
        ],
        'native': [
          'Ótimo, escolho 18 por cento na maquininha.',
          'Tem troco? Só tenho notas grandes.',
          'Aqui, isso é pra você.',
        ],
        'why': [
          'Recebe "escolher na maquininha" como foi dito',
          'Entendeu que se paga em dinheiro',
          'Entendeu que se entrega na mão',
        ],
      },
    ],
  },
  'builtin_t2': {
    'topic': 'A água é de graça?',
    'setting': 'Você acabou de sentar num restaurante',
    'ex': [
      {
        'line': 'Quer água? A água em garrafa custa três dólares, ou a água da torneira é de graça.',
        'gist': [
          'A de garrafa custa três dólares; a da torneira é de graça',
          'Toda água é de graça',
          'Toda água custa três dólares',
        ],
        'native': [
          'Água da torneira, por favor.',
          'Água em garrafa, por favor, já que é de graça.',
          'Três dólares por água da torneira? Não, obrigado.',
        ],
        'why': [
          'Recebe "a da torneira é de graça" e escolhe',
          'A de graça é a da torneira: ouviu errado',
          'Os três dólares são da garrafa: inverteu',
        ],
      },
      {
        'line': 'Claro. E um aviso: a cozinha está um pouco lenta hoje. A comida pode levar uns trinta minutos.',
        'gist': [
          'A comida pode levar uns trinta minutos hoje',
          'Fecham em trinta minutos, então é preciso correr',
          'A comida sai em três minutos',
        ],
        'native': [
          'Tudo bem, não estamos com pressa.',
          'Fecham em trinta minutos? Então pedimos agora.',
          'Só três minutos? Uau, que rápido.',
        ],
        'why': [
          'Recebe "vai demorar" como foi dito',
          'Ouviu "cozinha lenta" como "fechando"',
          'Ouviu trinta como três',
        ],
      },
    ],
  },
  'builtin_t3': {
    'topic': 'Sem reserva no hotel',
    'setting': 'Na recepção, fazendo check-in',
    'ex': [
      {
        'line': 'Desculpe, não encontro nenhuma reserva no seu nome para hoje. Será que é para amanhã?',
        'gist': [
          'Não encontra a reserva de hoje; pergunta se é para amanhã',
          'Há reserva para hoje; é preciso esperar o quarto',
          'Há reserva para amanhã, mas hoje está lotado',
        ],
        'native': [
          'Deveria ser para hoje. Aqui está o e-mail de confirmação, pode verificar pelo número da reserva?',
          'Tá, espero aqui até o quarto ficar pronto.',
          'Lotado hoje? Então pode indicar outro hotel?',
        ],
        'why': [
          'Responde a "não encontro, amanhã?" com uma prova',
          'Ouviu "sem reserva" como "quarto sendo preparado"',
          'Ninguém disse "lotado"',
        ],
      },
      {
        'line': 'Ah, encontrei. A reserva foi cancelada porque o seu cartão não funcionou. Ainda temos um quarto, mas o preço de hoje é vinte dólares mais caro.',
        'gist': [
          'Cancelada pelo cartão; há quarto, vinte dólares mais caro',
          'Cancelada pelo cartão; não há mais quartos',
          'A reserva está válida; mesmo preço',
        ],
        'native': [
          'Meu cartão não funcionou? Ninguém me avisou. Posso pagar agora pelo preço original?',
          'Não tem mais quarto? Então preciso achar outro hotel.',
          'Mesmo preço? Ótimo, pago agora.',
        ],
        'why': [
          'Recebe "cancelada, tem quarto, mais caro" e faz um pedido',
          'Ouviu "ainda temos um quarto" como "não há mais"',
          'Não ouviu "vinte dólares mais caro"',
        ],
      },
    ],
  },
  'builtin_t4': {
    'topic': 'Sem água quente',
    'setting': 'O chuveiro está sem água quente; você ligou para a recepção',
    'ex': [
      {
        'line': 'Sinto muito pela água quente. Posso mandar alguém consertar em uns trinta minutos, ou posso mudar você para outro quarto agora.',
        'gist': [
          'Conserto em trinta minutos, ou mudar de quarto agora',
          'Conserto amanhã; não dá para mudar de quarto',
          'Conserto agora mesmo; não precisa mudar',
        ],
        'native': [
          'Espero o conserto, obrigado. Trinta minutos está bom.',
          'Amanhã? É tarde demais. Preciso de água quente hoje.',
          'Agora mesmo? Ótimo, espero perto da porta.',
        ],
        'why': [
          'Recebe "conserto em trinta ou mudança agora" e escolhe',
          'Ouviu "trinta minutos" como "amanhã"',
          'O "agora" era a mudança de quarto, não o conserto',
        ],
      },
      {
        'line': 'Certo. Enquanto espera, pode usar a piscina na cobertura. Fica aberta até as dez.',
        'gist': [
          'Enquanto espera, a piscina da cobertura fica aberta até as dez',
          'A piscina está fechada hoje',
          'A piscina abre às dez',
        ],
        'native': [
          'Legal, vou à piscina então. Ligue para o meu quarto quando consertar.',
          'A piscina está fechada? Tá, fico no quarto.',
          'Abre às dez? É tarde demais pra mim.',
        ],
        'why': [
          'Recebe "aberta até as dez" como foi dito',
          'Ouviu "aberta" como "fechada"',
          'Ouviu "até as dez" como "a partir das dez"',
        ],
      },
    ],
  },
  'builtin_t5': {
    'topic': 'O preço no caixa',
    'setting': 'No caixa com um item que na prateleira dizia 20% de desconto',
    'ex': [
      {
        'line': 'São quarenta e oito dólares e cinquenta. O desconto de vinte por cento é só para membros, então não está incluído.',
        'gist': [
          'Total 48,50; o desconto de 20% é só para membros, não está incluído',
          'Total 48,50; o desconto de 20% já está aplicado',
          'Total vinte dólares; sem desconto',
        ],
        'native': [
          'Só membros? Posso virar membro agora?',
          'Ah, o desconto já está? Tá, aqui está meu cartão.',
          'Vinte dólares? Mais barato do que eu pensava.',
        ],
        'why': [
          'Recebe "só membros, não incluído" e age',
          'Ouviu "não incluído" como "incluído"',
          'Ouviu "vinte por cento" como "vinte dólares"',
        ],
      },
      {
        'line': 'Sim, é de graça. Só preciso do seu e-mail. Leva um minuto.',
        'gist': [
          'Virar membro é de graça; só um e-mail, um minuto',
          'Virar membro custa dinheiro e leva tempo',
          'Precisa de documento e hoje não dá',
        ],
        'native': [
          'Tá, vamos. Meu e-mail é…',
          'Custa dinheiro? Não, obrigado.',
          'Não estou com documento. Deixa pra lá.',
        ],
        'why': [
          'Recebe "de graça, e-mail, um minuto" e segue em frente',
          'Ouviu "de graça" como "custa dinheiro"',
          'O que precisa é um e-mail: ouviu errado',
        ],
      },
    ],
  },
};
