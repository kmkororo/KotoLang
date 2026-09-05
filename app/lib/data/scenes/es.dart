/// Español: tema, situación, traducción de la frase, las tres opciones de ①,
/// y la traducción y el motivo de cada respuesta de ②. La correcta va primero.
library;

const Map<String, Map<String, dynamic>> es = {
  'builtin_w1': {
    'topic': 'Rechazar una petición',
    'setting': 'Un compañero te pide que des su presentación del viernes',
    'ex': [
      {
        'line': '¿Estás libre el viernes por la tarde? Tengo dos reuniones a la misma hora. ¿Puedes hacer la presentación para el cliente a las tres por mí?',
        'gist': [
          'Quiere que des tú la presentación del viernes a las tres',
          'Quiere que le acompañes a una reunión el viernes a las tres',
          'Dice que puedes tomarte libre el viernes por la tarde',
        ],
        'native': [
          'El viernes a las tres me viene mal: entrego el informe entonces. ¿Podemos pedir al cliente pasarlo al lunes?',
          'Claro, me siento a tu lado y tomo notas.',
          '¡Gracias! Entonces me tomo libre el viernes por la tarde.',
        ],
        'why': [
          'Recibe la petición como tal y propone una alternativa',
          'Oyó «hazla por mí» como «ven conmigo»',
          'Oyó una petición como un permiso para irse',
        ],
      },
      {
        'line': 'El lunes es tarde: el cliente se va el sábado. ¿Podrías hacer solo los primeros diez minutos? Después me uno por teléfono.',
        'gist': [
          'Solo los primeros diez minutos; después se une por teléfono',
          'Toda la presentación; no puede estar',
          'Se pasó al lunes y empieza diez minutos antes',
        ],
        'native': [
          'Vale, diez minutos sí puedo. Mándame las primeras diapositivas y llama a las tres y diez.',
          '¿Toda la presentación? Lo siento, eso no puedo.',
          'El lunes va bien. Empecemos diez minutos antes.',
        ],
        'why': [
          'Recibe «diez minutos, luego por teléfono» tal como se dijo',
          'Oyó «los primeros diez minutos» como «toda la presentación»',
          'No oyó «el lunes es tarde»',
        ],
      },
    ],
  },
  'builtin_w2': {
    'topic': 'Cambiar una reunión',
    'setting': 'Tu jefe pregunta por mover la reunión de la semana que viene',
    'ex': [
      {
        'line': '¿Podemos mover la reunión de equipo de la semana que viene? El jueves ya no me va bien. ¿Qué tal el viernes a las nueve de la mañana?',
        'gist': [
          'Mover la reunión del jueves al viernes a las nueve',
          'Mover la reunión del viernes al jueves a las nueve',
          'Cancelar la reunión de la semana que viene',
        ],
        'native': [
          'El viernes a las nueve me va bien. Aviso a los demás.',
          'El jueves a las nueve me va bien.',
          '¿Sin reunión la semana que viene? Por mí, bien.',
        ],
        'why': [
          'Recibe «al viernes a las nueve» tal como se dijo',
          'Cambió jueves por viernes',
          'Oyó «mover» como «cancelar»',
        ],
      },
      {
        'line': 'Genial. Una cosa más: ¿puedes reservar la sala pequeña? La grande está ocupada el viernes.',
        'gist': [
          'Reservar la sala pequeña; la grande está ocupada el viernes',
          'Reservar la sala grande; la pequeña está ocupada',
          'Él reserva la sala; no hay que hacer nada',
        ],
        'native': [
          'Claro, reservo la sala pequeña para el viernes a las nueve.',
          'Vale, reservo la sala grande.',
          'Genial, entonces tú reservas la sala. ¡Gracias!',
        ],
        'why': [
          'Recibe «reserva tú la pequeña» tal como se dijo',
          'Cambió grande por pequeña',
          'Oyó una petición como algo que hará la otra persona',
        ],
      },
    ],
  },
  'builtin_w3': {
    'topic': 'Reconocer un error',
    'setting': 'Tu jefe, sobre una lista de precios que enviaste a un cliente',
    'ex': [
      {
        'line': 'Me ha escrito el cliente. Dice que la lista de precios tiene los números mal. ¿Qué archivo les enviaste?',
        'gist': [
          'El cliente dice que los números están mal; ¿qué archivo enviaste?',
          'El cliente dice que la lista no llegó',
          'Al cliente le gustó la lista',
        ],
        'native': [
          'Lo siento, creo que envié el archivo viejo. Lo compruebo ahora y mando el correcto.',
          '¿No lo recibieron? Lo vuelvo a enviar ahora.',
          '¡Gracias! Me alegra que les gustara.',
        ],
        'why': [
          'Responde al error y a la pregunta sobre el archivo',
          'Oyó «números mal» como «no llegó»',
          'Oyó una queja como un elogio',
        ],
      },
      {
        'line': 'No envíes nada todavía. Arregla el archivo, enséñamelo primero y luego lo enviamos juntos.',
        'gist': [
          'No enviar nada aún; arreglar, enseñárselo primero y enviar juntos',
          'Reenviar ya; informarle después',
          'Él lo arregla y lo envía',
        ],
        'native': [
          'Entendido. Lo arreglo y te lo enseño antes de que salga nada.',
          'Vale, estoy enviando el archivo nuevo ahora.',
          'Gracias por arreglarlo por mí.',
        ],
        'why': [
          'Recibe «todavía no, enséñamelo primero» tal como se dijo',
          'No oyó «no envíes nada todavía»',
          'Oyó «arréglalo tú» como «lo arreglo yo»',
        ],
      },
    ],
  },
  'builtin_w4': {
    'topic': 'Te piden quedarte más tarde',
    'setting': 'Justo antes de la hora de salir, un compañero',
    'ex': [
      {
        'line': 'Perdona que te lo pida, pero ¿podrías quedarte una hora más esta noche? El cliente adelantó la entrega a mañana por la mañana.',
        'gist': [
          'Quedarse una hora más esta noche; la entrega pasó a mañana por la mañana',
          'Venir una hora antes mañana; la entrega es mañana por la tarde',
          'Irse temprano hoy; la entrega pasó a la semana que viene',
        ],
        'native': [
          'Una hora está bien. ¿Por dónde empiezo?',
          'Claro, mañana vengo antes. ¿A qué hora?',
          '¡Genial, gracias! Hasta mañana entonces.',
        ],
        'why': [
          'Recibe «una hora esta noche» y se pone en marcha',
          'Oyó «quédate esta noche» como «ven antes mañana»',
          'Oyó «quédate» como «puedes irte»',
        ],
      },
      {
        'line': 'Gracias. ¿Puedes revisar los números del informe mientras termino las diapositivas? Solo los totales de la última página.',
        'gist': [
          'Revisar los totales de la última página del informe',
          'Terminar las diapositivas; él hace el informe',
          'Leer el informe entero de principio a fin',
        ],
        'native': [
          'Vale, solo los totales de la última página. Te aviso si algo no cuadra.',
          'Vale, termino las diapositivas. Mándame lo que tengas.',
          '¿Todo el informe? Eso lleva más de una hora.',
        ],
        'why': [
          'Recibe «solo los totales» tal como se dijo',
          'Intercambió las dos tareas',
          'Oyó «solo los totales» como «todo el informe»',
        ],
      },
    ],
  },
  'builtin_w5': {
    'topic': 'Recibir comentarios',
    'setting': 'Tu jefe, sobre un informe que entregaste',
    'ex': [
      {
        'line': 'Tu informe estaba bien, pero era demasiado largo. Nadie leyó la última página, y ahí estaba tu punto principal.',
        'gist': [
          'Era demasiado largo; el punto principal estaba al final y nadie lo leyó',
          'Era demasiado corto; faltaba el punto principal',
          'Estaba bien, sobre todo la última página',
        ],
        'native': [
          'Entiendo. Pondré el punto principal en la primera página y lo acortaré.',
          'Añadiré más páginas con más detalle.',
          '¡Gracias! Me esforcé mucho en la última página.',
        ],
        'why': [
          'Recibe «demasiado largo, lo principal al final» tal como se dijo',
          'Oyó «demasiado largo» como «demasiado corto»',
          'Oyó «nadie lo leyó» como «estaba bien»',
        ],
      },
      {
        'line': 'Bien. Y para los directores, haz una versión de una página. Solo tienen cinco minutos para leerla.',
        'gist': [
          'Una versión de una página para los directores; tienen cinco minutos',
          'Una versión de cinco páginas para los directores; tienen tiempo de sobra',
          'Los directores no necesitan nada',
        ],
        'native': [
          'Una página para los directores, entendido. Te la mando mañana.',
          '¿Cinco páginas para los directores? Vale, escribo más.',
          'Entonces los directores no necesitan copia. Entendido.',
        ],
        'why': [
          'Recibe «una página» tal como se dijo',
          'Oyó «una página, cinco minutos» como «cinco páginas»',
          'No oyó «haz una versión»',
        ],
      },
    ],
  },
  'builtin_t1': {
    'topic': 'La propina',
    'setting': 'Llega la cuenta tras cenar en un restaurante',
    'ex': [
      {
        'line': 'Aquí tiene la cuenta. Para que lo sepa, la propina no está incluida. La mayoría deja un 18 por ciento.',
        'gist': [
          'La propina no está incluida; lo normal es un 18 %',
          'La propina está incluida; no hay que añadir nada',
          'En este restaurante no se deja propina',
        ],
        'native': [
          'Vale, gracias. Añado el 18 por ciento.',
          'Ah, ¿está incluida? Entonces pago solo esto.',
          '¿Sin propina aquí? Genial, gracias.',
        ],
        'why': [
          'Recibe «no incluida, 18 %» tal como se dijo',
          'Oyó «no incluida» como «incluida»',
          'Oyó «dejar propina» como «sin propina»',
        ],
      },
      {
        'line': 'Puede añadirla en el datáfono. Le pedirá elegir un porcentaje.',
        'gist': [
          'Se añade en el datáfono eligiendo un porcentaje',
          'Se deja en efectivo sobre la mesa',
          'Se entrega en mano al camarero',
        ],
        'native': [
          'Genial, elijo el 18 por ciento en el aparato.',
          '¿Tiene cambio? Solo llevo billetes grandes.',
          'Tenga, esto es para usted.',
        ],
        'why': [
          'Recibe «elegir en el aparato» tal como se dijo',
          'Entendió que se paga en efectivo',
          'Entendió que se entrega en mano',
        ],
      },
    ],
  },
  'builtin_t2': {
    'topic': '¿El agua es gratis?',
    'setting': 'Acabas de sentarte en un restaurante',
    'ex': [
      {
        'line': '¿Quiere agua? El agua embotellada cuesta tres dólares, o el agua del grifo es gratis.',
        'gist': [
          'La embotellada cuesta tres dólares; la del grifo es gratis',
          'Toda el agua es gratis',
          'Toda el agua cuesta tres dólares',
        ],
        'native': [
          'Agua del grifo, por favor.',
          'Embotellada, por favor, ya que es gratis.',
          '¿Tres dólares por agua del grifo? No, gracias.',
        ],
        'why': [
          'Recibe «la del grifo es gratis» y elige',
          'La gratis es la del grifo: lo oyó mal',
          'Los tres dólares son de la embotellada: lo invirtió',
        ],
      },
      {
        'line': 'Claro. Y un aviso: la cocina va un poco lenta esta noche. La comida puede tardar unos treinta minutos.',
        'gist': [
          'La comida puede tardar unos treinta minutos esta noche',
          'Cierran en treinta minutos, así que hay que darse prisa',
          'La comida sale en tres minutos',
        ],
        'native': [
          'No pasa nada, no tenemos prisa.',
          '¿Cierran en treinta minutos? Entonces pedimos ya.',
          '¿Solo tres minutos? Vaya, qué rápido.',
        ],
        'why': [
          'Recibe «va a tardar» tal como se dijo',
          'Oyó «cocina lenta» como «cierran»',
          'Oyó treinta como tres',
        ],
      },
    ],
  },
  'builtin_t3': {
    'topic': 'No hay reserva en el hotel',
    'setting': 'En recepción, haciendo el check-in',
    'ex': [
      {
        'line': 'Lo siento, no encuentro ninguna reserva a su nombre para esta noche. ¿Será quizá para mañana?',
        'gist': [
          'No encuentra la reserva de esta noche; pregunta si es para mañana',
          'Hay reserva para esta noche; hay que esperar la habitación',
          'Hay reserva para mañana, pero esta noche está lleno',
        ],
        'native': [
          'Debería ser para esta noche. Aquí está el correo de confirmación, ¿puede buscar por el número de reserva?',
          'Vale, espero aquí hasta que la habitación esté lista.',
          '¿Lleno esta noche? ¿Me recomienda otro hotel entonces?',
        ],
        'why': [
          'Responde a «no la encuentro, ¿mañana?» con una prueba',
          'Oyó «sin reserva» como «habitación en preparación»',
          'Nadie dijo «lleno»',
        ],
      },
      {
        'line': 'Ah, ya la encontré. La reserva se canceló porque su tarjeta no funcionó. Aún tenemos habitación, pero el precio de esta noche es veinte dólares más.',
        'gist': [
          'Se canceló por la tarjeta; queda habitación, veinte dólares más cara',
          'Se canceló por la tarjeta; no quedan habitaciones',
          'La reserva es válida; mismo precio',
        ],
        'native': [
          '¿Mi tarjeta no funcionó? Nadie me avisó. ¿Puedo pagar ahora al precio original?',
          '¿No quedan habitaciones? Entonces tengo que buscar otro hotel.',
          '¿El mismo precio? Genial, pago ahora.',
        ],
        'why': [
          'Recibe «cancelada, hay habitación, más cara» y pide algo',
          'Oyó «aún tenemos habitación» como «no quedan»',
          'No oyó «veinte dólares más»',
        ],
      },
    ],
  },
  'builtin_t4': {
    'topic': 'Sin agua caliente',
    'setting': 'La ducha no tiene agua caliente; llamaste a recepción',
    'ex': [
      {
        'line': 'Siento lo del agua caliente. Puedo enviar a alguien a arreglarlo en unos treinta minutos, o puedo cambiarle a otra habitación ahora.',
        'gist': [
          'Reparación en treinta minutos, o cambiar de habitación ahora',
          'Reparación mañana; no se puede cambiar de habitación',
          'Reparación ahora mismo; no hace falta cambiarse',
        ],
        'native': [
          'Espero la reparación, gracias. Treinta minutos está bien.',
          '¿Mañana? Es muy tarde. Necesito agua caliente esta noche.',
          '¿Ahora mismo? Genial, espero junto a la puerta.',
        ],
        'why': [
          'Recibe «reparación en treinta o cambio ahora» y elige',
          'Oyó «treinta minutos» como «mañana»',
          'Lo de «ahora» era el cambio de habitación, no la reparación',
        ],
      },
      {
        'line': 'De acuerdo. Mientras espera, puede usar la piscina de la azotea. Está abierta hasta las diez.',
        'gist': [
          'Mientras espera, la piscina de la azotea está abierta hasta las diez',
          'La piscina está cerrada hoy',
          'La piscina abre a las diez',
        ],
        'native': [
          'Genial, entonces voy a la piscina. Llame a mi habitación cuando esté arreglado.',
          '¿La piscina está cerrada? Vale, me quedo en la habitación.',
          '¿Abre a las diez? Es muy tarde para mí.',
        ],
        'why': [
          'Recibe «abierta hasta las diez» tal como se dijo',
          'Oyó «abierta» como «cerrada»',
          'Oyó «hasta las diez» como «desde las diez»',
        ],
      },
    ],
  },
  'builtin_t5': {
    'topic': 'El precio en caja',
    'setting': 'En caja con un artículo que en el estante decía 20 % de descuento',
    'ex': [
      {
        'line': 'Son cuarenta y ocho dólares con cincuenta. El veinte por ciento de descuento es solo para socios, así que no está incluido.',
        'gist': [
          'Total 48,50; el 20 % es solo para socios, no está incluido',
          'Total 48,50; el 20 % ya está aplicado',
          'Total veinte dólares; sin descuento',
        ],
        'native': [
          '¿Solo socios? ¿Puedo hacerme socio ahora?',
          'Ah, ¿el descuento ya está? Vale, aquí está mi tarjeta.',
          '¿Veinte dólares? Más barato de lo que pensaba.',
        ],
        'why': [
          'Recibe «solo socios, no incluido» y actúa',
          'Oyó «no incluido» como «incluido»',
          'Oyó «veinte por ciento» como «veinte dólares»',
        ],
      },
      {
        'line': 'Sí, es gratis. Solo necesito su correo electrónico. Tarda un minuto.',
        'gist': [
          'Hacerse socio es gratis; solo un correo, un minuto',
          'Hacerse socio cuesta dinero y lleva tiempo',
          'Hace falta un documento y hoy no se puede',
        ],
        'native': [
          'Vale, hagámoslo. Mi correo es…',
          '¿Cuesta dinero? No, gracias.',
          'No llevo el documento. Déjelo.',
        ],
        'why': [
          'Recibe «gratis, correo, un minuto» y sigue adelante',
          'Oyó «gratis» como «cuesta dinero»',
          'Lo que hace falta es un correo: lo oyó mal',
        ],
      },
    ],
  },
};
