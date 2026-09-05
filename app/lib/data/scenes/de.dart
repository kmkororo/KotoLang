/// Deutsch: Thema, Situation, Übersetzung des Satzes, die drei Auswahlen von ①
/// sowie Übersetzung und Begründung jeder Antwort von ②. Die richtige zuerst.
library;

const Map<String, Map<String, dynamic>> de = {
  'builtin_w1': {
    'topic': 'Eine Bitte ablehnen',
    'setting': 'Ein Kollege bittet dich, seine Präsentation am Freitag zu halten',
    'ex': [
      {
        'line': 'Hast du Freitagnachmittag Zeit? Ich habe zwei Besprechungen gleichzeitig. Kannst du die Kundenpräsentation um drei für mich übernehmen?',
        'gist': [
          'Du sollst die Präsentation am Freitag um drei halten',
          'Du sollst am Freitag um drei mit in eine Besprechung kommen',
          'Er sagt, du kannst Freitagnachmittag freinehmen',
        ],
        'native': [
          'Freitag um drei ist schwierig, da ist mein Bericht fällig. Können wir den Kunden fragen, ob Montag geht?',
          'Klar, ich setze mich neben dich und mache Notizen.',
          'Danke! Dann nehme ich mir den Freitagnachmittag frei.',
        ],
        'why': [
          'Nimmt die Bitte als Bitte und bietet einen Ausweg an',
          '„Für mich übernehmen“ als „mitkommen“ verstanden',
          'Eine Bitte als Erlaubnis zum Freinehmen verstanden',
        ],
      },
      {
        'line': 'Montag ist zu spät, der Kunde reist am Samstag ab. Könntest du nur die ersten zehn Minuten machen? Danach schalte ich mich per Telefon dazu.',
        'gist': [
          'Nur die ersten zehn Minuten; danach ist er per Telefon dabei',
          'Die ganze Präsentation; er kann gar nicht dabei sein',
          'Es wurde auf Montag verschoben und beginnt zehn Minuten früher',
        ],
        'native': [
          'Okay, zehn Minuten schaffe ich. Schick mir die ersten Folien und ruf um zehn nach drei an.',
          'Die ganze Präsentation? Tut mir leid, das kann ich nicht.',
          'Montag passt. Fangen wir zehn Minuten früher an.',
        ],
        'why': [
          '„Zehn Minuten, dann per Telefon“ wie gesagt aufgenommen',
          '„Die ersten zehn Minuten“ als „die ganze Präsentation“ verstanden',
          '„Montag ist zu spät“ überhört',
        ],
      },
    ],
  },
  'builtin_w2': {
    'topic': 'Ein Meeting verschieben',
    'setting': 'Deine Chefin fragt, ob das Meeting nächste Woche verschoben werden kann',
    'ex': [
      {
        'line': 'Können wir das Teammeeting nächste Woche verschieben? Donnerstag passt mir nicht mehr. Wie wäre Freitagmorgen um neun?',
        'gist': [
          'Das Donnerstagsmeeting auf Freitag um neun verschieben',
          'Das Freitagsmeeting auf Donnerstag um neun verschieben',
          'Das Meeting nächste Woche absagen',
        ],
        'native': [
          'Freitag um neun passt mir. Ich sage den anderen Bescheid.',
          'Donnerstag um neun passt mir.',
          'Kein Meeting nächste Woche? Passt mir.',
        ],
        'why': [
          '„Auf Freitag um neun“ wie gesagt aufgenommen',
          'Donnerstag und Freitag vertauscht',
          '„Verschieben“ als „absagen“ verstanden',
        ],
      },
      {
        'line': 'Super. Noch etwas: Kannst du den kleinen Raum buchen? Der große ist am Freitag belegt.',
        'gist': [
          'Den kleinen Raum buchen; der große ist am Freitag belegt',
          'Den großen Raum buchen; der kleine ist belegt',
          'Sie bucht den Raum selbst; nichts zu tun',
        ],
        'native': [
          'Klar, ich buche den kleinen Raum für Freitag um neun.',
          'Okay, ich buche den großen Raum.',
          'Super, dann buchst du den Raum. Danke!',
        ],
        'why': [
          '„Du buchst den kleinen“ wie gesagt aufgenommen',
          'Groß und klein vertauscht',
          'Eine Bitte als etwas verstanden, das die andere Person tut',
        ],
      },
    ],
  },
  'builtin_w3': {
    'topic': 'Zu einem Fehler stehen',
    'setting': 'Deine Chefin, wegen einer Preisliste, die du einem Kunden geschickt hast',
    'ex': [
      {
        'line': 'Ich habe eine E-Mail vom Kunden. Sie sagen, die Preisliste hat die falschen Zahlen. Welche Datei hast du ihnen geschickt?',
        'gist': [
          'Der Kunde sagt, die Zahlen sind falsch; welche Datei hast du geschickt?',
          'Der Kunde sagt, die Liste ist nie angekommen',
          'Dem Kunden hat die Liste gefallen',
        ],
        'native': [
          'Es tut mir leid, ich glaube, ich habe die alte Datei geschickt. Ich prüfe das sofort und schicke die richtige.',
          'Sie haben sie nicht bekommen? Ich schicke sie gleich noch mal.',
          'Danke! Schön, dass sie ihnen gefallen hat.',
        ],
        'why': [
          'Antwortet auf den Fehler und die Frage nach der Datei',
          '„Falsche Zahlen“ als „nicht angekommen“ verstanden',
          'Eine Beschwerde als Lob verstanden',
        ],
      },
      {
        'line': 'Schick noch nichts. Korrigiere die Datei, zeig sie mir zuerst, und dann schicken wir sie zusammen.',
        'gist': [
          'Noch nichts schicken; korrigieren, zuerst zeigen, dann gemeinsam schicken',
          'Sofort neu schicken; später Bescheid geben',
          'Sie korrigiert und schickt es selbst',
        ],
        'native': [
          'Verstanden. Ich korrigiere sie und zeige sie Ihnen, bevor etwas rausgeht.',
          'Okay, ich schicke die neue Datei jetzt.',
          'Danke, dass Sie das für mich korrigiert haben.',
        ],
        'why': [
          '„Noch nicht, zeig sie mir zuerst“ wie gesagt aufgenommen',
          '„Schick noch nichts“ überhört',
          '„Du korrigierst“ als „ich korrigiere“ verstanden',
        ],
      },
    ],
  },
  'builtin_w4': {
    'topic': 'Um Überstunden gebeten',
    'setting': 'Kurz vor Feierabend, ein Kollege',
    'ex': [
      {
        'line': 'Tut mir leid, dass ich frage, aber könntest du heute Abend eine Stunde länger bleiben? Der Kunde hat die Frist auf morgen früh vorgezogen.',
        'gist': [
          'Heute Abend eine Stunde länger bleiben; die Frist ist jetzt morgen früh',
          'Morgen eine Stunde früher kommen; die Frist ist morgen Abend',
          'Heute früher gehen; die Frist wurde auf nächste Woche verschoben',
        ],
        'native': [
          'Eine Stunde ist okay. Womit soll ich anfangen?',
          'Klar, ich komme morgen früher. Um wie viel Uhr?',
          'Super, danke! Dann bis morgen.',
        ],
        'why': [
          '„Eine Stunde heute Abend“ aufgenommen und losgelegt',
          '„Heute Abend bleiben“ als „morgen früher kommen“ verstanden',
          '„Bleiben“ als „du kannst gehen“ verstanden',
        ],
      },
      {
        'line': 'Danke. Könntest du die Zahlen im Bericht prüfen, während ich die Folien fertig mache? Nur die Summen auf der letzten Seite.',
        'gist': [
          'Die Summen auf der letzten Seite des Berichts prüfen',
          'Die Folien fertig machen; er übernimmt den Bericht',
          'Den ganzen Bericht von vorn bis hinten lesen',
        ],
        'native': [
          'Alles klar, nur die Summen auf der letzten Seite. Ich sage dir, wenn etwas komisch aussieht.',
          'Okay, ich mache die Folien fertig. Schick mir, was du hast.',
          'Den ganzen Bericht? Das dauert länger als eine Stunde.',
        ],
        'why': [
          '„Nur die Summen“ wie gesagt aufgenommen',
          'Die beiden Aufgaben vertauscht',
          '„Nur die Summen“ als „den ganzen Bericht“ verstanden',
        ],
      },
    ],
  },
  'builtin_w5': {
    'topic': 'Feedback annehmen',
    'setting': 'Deine Chefin, zu einem Bericht, den du abgegeben hast',
    'ex': [
      {
        'line': 'Dein Bericht war gut, aber zu lang. Niemand hat die letzte Seite gelesen, und genau da stand dein Hauptpunkt.',
        'gist': [
          'Zu lang; der Hauptpunkt stand auf der letzten Seite, und niemand hat sie gelesen',
          'Zu kurz; der Hauptpunkt fehlte',
          'Gut, besonders die letzte Seite',
        ],
        'native': [
          'Verstehe. Ich stelle den Hauptpunkt auf die erste Seite und kürze.',
          'Ich füge mehr Seiten mit mehr Details hinzu.',
          'Danke! An der letzten Seite habe ich viel gearbeitet.',
        ],
        'why': [
          '„Zu lang, Hauptpunkt am Ende“ wie gesagt aufgenommen',
          '„Zu lang“ als „zu kurz“ verstanden',
          '„Niemand hat sie gelesen“ als „sie war gut“ verstanden',
        ],
      },
      {
        'line': 'Gut. Und für die Führungskräfte mach eine Version auf einer Seite. Sie haben nur fünf Minuten zum Lesen.',
        'gist': [
          'Eine einseitige Version für die Führungskräfte; sie haben fünf Minuten',
          'Eine fünfseitige Version für die Führungskräfte; sie haben viel Zeit',
          'Die Führungskräfte brauchen nichts',
        ],
        'native': [
          'Eine Seite für die Führungskräfte, verstanden. Ich schicke sie Ihnen morgen.',
          'Fünf Seiten für die Führungskräfte? Okay, ich schreibe mehr.',
          'Die Führungskräfte brauchen also keine Kopie. Verstanden.',
        ],
        'why': [
          '„Eine Seite“ wie gesagt aufgenommen',
          '„Eine Seite, fünf Minuten“ als „fünf Seiten“ verstanden',
          '„Mach eine Version“ überhört',
        ],
      },
    ],
  },
  'builtin_t1': {
    'topic': 'Trinkgeld',
    'setting': 'Nach dem Abendessen im Restaurant kommt die Rechnung',
    'ex': [
      {
        'line': 'Hier ist Ihre Rechnung. Nur zur Info: Das Trinkgeld ist nicht enthalten. Die meisten geben etwa 18 Prozent.',
        'gist': [
          'Trinkgeld ist nicht enthalten; etwa 18 % sind üblich',
          'Trinkgeld ist enthalten; nichts hinzuzufügen',
          'In diesem Restaurant gibt es kein Trinkgeld',
        ],
        'native': [
          'Okay, danke. Ich gebe 18 Prozent dazu.',
          'Oh, es ist enthalten? Dann zahle ich nur das.',
          'Kein Trinkgeld hier? Super, danke.',
        ],
        'why': [
          '„Nicht enthalten, 18 %“ wie gesagt aufgenommen',
          '„Nicht enthalten“ als „enthalten“ verstanden',
          '„Trinkgeld geben“ als „kein Trinkgeld“ verstanden',
        ],
      },
      {
        'line': 'Sie können es am Kartengerät hinzufügen. Es fragt Sie nach einem Prozentsatz.',
        'gist': [
          'Am Kartengerät hinzufügen, indem man einen Prozentsatz wählt',
          'Bar auf dem Tisch liegen lassen',
          'Der Bedienung in die Hand geben',
        ],
        'native': [
          'Gut, ich wähle 18 Prozent am Gerät.',
          'Haben Sie Wechselgeld? Ich habe nur große Scheine.',
          'Hier, das ist für Sie.',
        ],
        'why': [
          '„Am Gerät wählen“ wie gesagt aufgenommen',
          'Als Barzahlung verstanden',
          'Als Übergabe in die Hand verstanden',
        ],
      },
    ],
  },
  'builtin_t2': {
    'topic': 'Ist das Wasser kostenlos?',
    'setting': 'Gerade im Restaurant Platz genommen',
    'ex': [
      {
        'line': 'Möchten Sie Wasser? Flaschenwasser kostet drei Dollar, oder Leitungswasser ist kostenlos.',
        'gist': [
          'Flaschenwasser kostet drei Dollar; Leitungswasser ist kostenlos',
          'Alles Wasser ist kostenlos',
          'Alles Wasser kostet drei Dollar',
        ],
        'native': [
          'Leitungswasser, bitte.',
          'Flaschenwasser, bitte, wo es doch kostenlos ist.',
          'Drei Dollar für Leitungswasser? Nein, danke.',
        ],
        'why': [
          '„Leitungswasser ist kostenlos“ aufgenommen und gewählt',
          'Kostenlos ist das Leitungswasser: falsch gehört',
          'Die drei Dollar gelten für die Flasche: vertauscht',
        ],
      },
      {
        'line': 'Gern. Und ein Hinweis: Die Küche ist heute Abend etwas langsam. Ihr Essen kann etwa dreißig Minuten dauern.',
        'gist': [
          'Das Essen kann heute Abend etwa dreißig Minuten dauern',
          'Sie schließen in dreißig Minuten, also schnell bestellen',
          'Das Essen kommt in drei Minuten',
        ],
        'native': [
          'Kein Problem, wir haben es nicht eilig.',
          'Sie schließen in dreißig Minuten? Dann bestellen wir jetzt.',
          'Nur drei Minuten? Wow, das ist schnell.',
        ],
        'why': [
          '„Es dauert eine Weile“ wie gesagt aufgenommen',
          '„Langsame Küche“ als „Schließung“ verstanden',
          'Dreißig als drei gehört',
        ],
      },
    ],
  },
  'builtin_t3': {
    'topic': 'Keine Buchung im Hotel',
    'setting': 'Beim Einchecken an der Rezeption',
    'ex': [
      {
        'line': 'Es tut mir leid, ich finde keine Buchung auf Ihren Namen für heute Nacht. Ist sie vielleicht für morgen?',
        'gist': [
          'Keine Buchung für heute gefunden; fragt, ob sie für morgen ist',
          'Es gibt eine Buchung für heute; auf das Zimmer warten',
          'Es gibt eine Buchung für morgen, aber heute ist alles voll',
        ],
        'native': [
          'Sie sollte für heute sein. Hier ist meine Bestätigungs-E-Mail, können Sie die Buchungsnummer prüfen?',
          'Okay, ich warte hier, bis das Zimmer fertig ist.',
          'Heute voll? Können Sie mir dann ein anderes Hotel empfehlen?',
        ],
        'why': [
          'Antwortet auf „nicht gefunden, morgen?“ mit einem Beleg',
          '„Keine Buchung“ als „Zimmer wird vorbereitet“ verstanden',
          'Niemand hat „voll“ gesagt',
        ],
      },
      {
        'line': 'Ah, ich habe sie gefunden. Die Buchung wurde storniert, weil Ihre Karte nicht funktioniert hat. Wir haben noch ein Zimmer, aber der Preis heute ist zwanzig Dollar höher.',
        'gist': [
          'Wegen der Karte storniert; ein Zimmer ist frei, zwanzig Dollar teurer',
          'Wegen der Karte storniert; keine Zimmer mehr',
          'Die Buchung ist gültig; gleicher Preis',
        ],
        'native': [
          'Meine Karte hat nicht funktioniert? Niemand hat mir Bescheid gesagt. Kann ich jetzt zum ursprünglichen Preis zahlen?',
          'Keine Zimmer mehr? Dann muss ich ein anderes Hotel suchen.',
          'Gleicher Preis? Super, ich zahle jetzt.',
        ],
        'why': [
          '„Storniert, Zimmer frei, teurer“ aufgenommen und darum gebeten',
          '„Wir haben noch ein Zimmer“ als „keine mehr“ verstanden',
          '„Zwanzig Dollar höher“ überhört',
        ],
      },
    ],
  },
  'builtin_t4': {
    'topic': 'Kein warmes Wasser',
    'setting': 'Die Dusche hat kein warmes Wasser; du hast die Rezeption angerufen',
    'ex': [
      {
        'line': 'Das mit dem warmen Wasser tut mir leid. Ich kann in etwa dreißig Minuten jemanden zur Reparatur schicken, oder ich verlege Sie jetzt in ein anderes Zimmer.',
        'gist': [
          'Reparatur in dreißig Minuten oder jetzt in ein anderes Zimmer',
          'Reparatur morgen; kein Zimmerwechsel möglich',
          'Reparatur sofort; kein Wechsel nötig',
        ],
        'native': [
          'Ich warte auf die Reparatur, danke. Dreißig Minuten sind okay.',
          'Morgen? Das ist zu spät. Ich brauche heute Abend warmes Wasser.',
          'Sofort? Super, ich warte an der Tür.',
        ],
        'why': [
          '„Reparatur in dreißig oder Wechsel jetzt“ aufgenommen und gewählt',
          '„Dreißig Minuten“ als „morgen“ verstanden',
          '„Jetzt“ galt dem Zimmerwechsel, nicht der Reparatur',
        ],
      },
      {
        'line': 'Gut. Während Sie warten, können Sie den Pool auf dem Dach nutzen. Er ist bis zehn geöffnet.',
        'gist': [
          'Währenddessen ist der Dachpool bis zehn geöffnet',
          'Der Pool ist heute geschlossen',
          'Der Pool öffnet um zehn',
        ],
        'native': [
          'Schön, dann gehe ich zum Pool. Bitte rufen Sie mein Zimmer an, wenn es repariert ist.',
          'Der Pool ist geschlossen? Okay, ich bleibe im Zimmer.',
          'Er öffnet um zehn? Das ist zu spät für mich.',
        ],
        'why': [
          '„Bis zehn geöffnet“ wie gesagt aufgenommen',
          '„Geöffnet“ als „geschlossen“ verstanden',
          '„Bis zehn“ als „ab zehn“ verstanden',
        ],
      },
    ],
  },
  'builtin_t5': {
    'topic': 'Der Preis an der Kasse',
    'setting': 'An der Kasse mit einem Artikel, der im Regal mit 20 % Rabatt stand',
    'ex': [
      {
        'line': 'Das macht achtundvierzig Dollar fünfzig. Die zwanzig Prozent Rabatt gelten nur für Mitglieder, sie sind also nicht enthalten.',
        'gist': [
          'Summe 48,50; die 20 % gelten nur für Mitglieder, nicht enthalten',
          'Summe 48,50; die 20 % sind schon abgezogen',
          'Summe zwanzig Dollar; kein Rabatt',
        ],
        'native': [
          'Nur Mitglieder? Kann ich jetzt Mitglied werden?',
          'Oh, der Rabatt ist drin? Okay, hier ist meine Karte.',
          'Zwanzig Dollar? Billiger als gedacht.',
        ],
        'why': [
          '„Nur Mitglieder, nicht enthalten“ aufgenommen und gehandelt',
          '„Nicht enthalten“ als „enthalten“ verstanden',
          '„Zwanzig Prozent“ als „zwanzig Dollar“ verstanden',
        ],
      },
      {
        'line': 'Ja, das ist kostenlos. Ich brauche nur Ihre E-Mail-Adresse. Es dauert eine Minute.',
        'gist': [
          'Mitglied werden ist kostenlos; nur eine E-Mail, eine Minute',
          'Mitglied werden kostet Geld und dauert',
          'Man braucht einen Ausweis, und heute geht es nicht',
        ],
        'native': [
          'Okay, machen wir das. Meine E-Mail ist …',
          'Es kostet Geld? Nein, danke.',
          'Ich habe meinen Ausweis nicht dabei. Lassen wir das.',
        ],
        'why': [
          '„Kostenlos, E-Mail, eine Minute“ aufgenommen und weitergemacht',
          '„Kostenlos“ als „kostet Geld“ verstanden',
          'Gebraucht wird eine E-Mail-Adresse: falsch gehört',
        ],
      },
    ],
  },
};
