/// Français : thème, situation, traduction de la réplique, les trois choix de ①,
/// et la traduction et la raison de chaque réponse de ②. La bonne vient en tête.
library;

const Map<String, Map<String, dynamic>> fr = {
  'builtin_w1': {
    'topic': 'Refuser une demande',
    'setting': 'Un collègue vous demande de faire sa présentation de vendredi',
    'ex': [
      {
        'line': 'Tu es libre vendredi après-midi ? J\'ai deux réunions en même temps. Tu peux faire la présentation client à quinze heures à ma place ?',
        'gist': [
          'Il veut que vous fassiez la présentation vendredi à quinze heures',
          'Il veut que vous assistiez à une réunion avec lui vendredi à quinze heures',
          'Il dit que vous pouvez prendre votre vendredi après-midi',
        ],
        'native': [
          'Vendredi quinze heures, c\'est compliqué : mon rapport est dû à ce moment-là. On peut demander au client de passer à lundi ?',
          'Bien sûr, je m\'assieds à côté de toi et je prends des notes.',
          'Merci ! Alors je prends mon vendredi après-midi.',
        ],
        'why': [
          'Reçoit la demande comme telle et propose une alternative',
          'A entendu « à ma place » comme « avec moi »',
          'A entendu une demande comme une permission de partir',
        ],
      },
      {
        'line': 'Lundi, c\'est trop tard : le client repart samedi. Tu pourrais faire juste les dix premières minutes ? Je prends le relais par téléphone ensuite.',
        'gist': [
          'Seulement les dix premières minutes ; il prend le relais par téléphone',
          'Toute la présentation ; il ne peut pas être là',
          'C\'est reporté à lundi et ça commence dix minutes plus tôt',
        ],
        'native': [
          'D\'accord, dix minutes, je peux. Envoie-moi les premières diapos et appelle à quinze heures dix.',
          'Toute la présentation ? Désolé, ça je ne peux pas.',
          'Lundi, ça marche. Commençons dix minutes plus tôt.',
        ],
        'why': [
          'Reçoit « dix minutes, puis par téléphone » tel que dit',
          'A entendu « les dix premières minutes » comme « toute la présentation »',
          'N\'a pas entendu « lundi, c\'est trop tard »',
        ],
      },
    ],
  },
  'builtin_w2': {
    'topic': 'Déplacer une réunion',
    'setting': 'Votre responsable veut déplacer la réunion de la semaine prochaine',
    'ex': [
      {
        'line': 'On peut déplacer la réunion d\'équipe de la semaine prochaine ? Jeudi ne me convient plus. Vendredi matin à neuf heures, ça irait ?',
        'gist': [
          'Déplacer la réunion de jeudi à vendredi neuf heures',
          'Déplacer la réunion de vendredi à jeudi neuf heures',
          'Annuler la réunion de la semaine prochaine',
        ],
        'native': [
          'Vendredi neuf heures, ça me va. Je préviens les autres.',
          'Jeudi neuf heures, ça me va.',
          'Pas de réunion la semaine prochaine ? Ça me va.',
        ],
        'why': [
          'Reçoit « à vendredi neuf heures » tel que dit',
          'A inversé jeudi et vendredi',
          'A entendu « déplacer » comme « annuler »',
        ],
      },
      {
        'line': 'Parfait. Encore une chose : tu peux réserver la petite salle ? La grande est prise vendredi.',
        'gist': [
          'Réserver la petite salle ; la grande est prise vendredi',
          'Réserver la grande salle ; la petite est prise',
          'Il réserve lui-même la salle ; rien à faire',
        ],
        'native': [
          'Bien sûr, je réserve la petite salle pour vendredi neuf heures.',
          'D\'accord, je réserve la grande salle.',
          'Parfait, donc c\'est toi qui réserves la salle. Merci !',
        ],
        'why': [
          'Reçoit « réserve la petite » tel que dit',
          'A inversé grande et petite',
          'A entendu une demande comme quelque chose que l\'autre fera',
        ],
      },
    ],
  },
  'builtin_w3': {
    'topic': 'Reconnaître une erreur',
    'setting': 'Votre responsable, à propos d\'une liste de prix envoyée à un client',
    'ex': [
      {
        'line': 'J\'ai reçu un e-mail du client. Ils disent que la liste de prix a les mauvais chiffres. Quel fichier tu leur as envoyé ?',
        'gist': [
          'Le client dit que les chiffres sont faux ; quel fichier avez-vous envoyé ?',
          'Le client dit que la liste n\'est pas arrivée',
          'Le client a aimé la liste',
        ],
        'native': [
          'Désolé, je crois avoir envoyé l\'ancien fichier. Je vérifie tout de suite et j\'envoie le bon.',
          'Ils ne l\'ont pas reçu ? Je le renvoie maintenant.',
          'Merci ! Je suis content que ça leur ait plu.',
        ],
        'why': [
          'Répond à l\'erreur et à la question sur le fichier',
          'A entendu « mauvais chiffres » comme « pas arrivé »',
          'A entendu une plainte comme un compliment',
        ],
      },
      {
        'line': 'N\'envoie rien pour l\'instant. Corrige le fichier, montre-le-moi d\'abord, et on l\'enverra ensemble.',
        'gist': [
          'Ne rien envoyer encore ; corriger, montrer d\'abord, envoyer ensemble',
          'Renvoyer tout de suite ; prévenir après',
          'Il corrige et envoie lui-même',
        ],
        'native': [
          'Compris. Je corrige et je vous le montre avant que rien ne parte.',
          'D\'accord, j\'envoie le nouveau fichier maintenant.',
          'Merci de l\'avoir corrigé pour moi.',
        ],
        'why': [
          'Reçoit « pas encore, montre-le-moi d\'abord » tel que dit',
          'N\'a pas entendu « n\'envoie rien pour l\'instant »',
          'A entendu « corrige-le » comme « je le corrige »',
        ],
      },
    ],
  },
  'builtin_w4': {
    'topic': 'On vous demande de rester tard',
    'setting': 'Juste avant la fin de la journée, un collègue',
    'ex': [
      {
        'line': 'Désolé de te demander ça, mais tu pourrais rester une heure de plus ce soir ? Le client a avancé la date limite à demain matin.',
        'gist': [
          'Rester une heure de plus ce soir ; la date limite est passée à demain matin',
          'Venir une heure plus tôt demain ; la date limite est demain soir',
          'Partir tôt ce soir ; la date limite est passée à la semaine prochaine',
        ],
        'native': [
          'Une heure, ça va. Par quoi je commence ?',
          'Bien sûr, je viens plus tôt demain. À quelle heure ?',
          'Super, merci ! À demain alors.',
        ],
        'why': [
          'Reçoit « une heure ce soir » et se met au travail',
          'A entendu « rester ce soir » comme « venir tôt demain »',
          'A entendu « rester » comme « tu peux partir »',
        ],
      },
      {
        'line': 'Merci. Tu peux vérifier les chiffres du rapport pendant que je finis les diapos ? Juste les totaux de la dernière page.',
        'gist': [
          'Vérifier les totaux de la dernière page du rapport',
          'Finir les diapos ; il s\'occupe du rapport',
          'Lire tout le rapport du début à la fin',
        ],
        'native': [
          'Compris, juste les totaux de la dernière page. Je te dis si quelque chose cloche.',
          'D\'accord, je finis les diapos. Envoie-moi ce que tu as.',
          'Tout le rapport ? Ça prendra plus d\'une heure.',
        ],
        'why': [
          'Reçoit « juste les totaux » tel que dit',
          'A inversé les deux tâches',
          'A entendu « juste les totaux » comme « tout le rapport »',
        ],
      },
    ],
  },
  'builtin_w5': {
    'topic': 'Recevoir un retour',
    'setting': 'Votre responsable, à propos d\'un rapport que vous avez remis',
    'ex': [
      {
        'line': 'Ton rapport était bien, mais trop long. Personne n\'a lu la dernière page, et c\'est là qu\'était ton point principal.',
        'gist': [
          'Trop long ; le point principal était en dernière page et personne ne l\'a lu',
          'Trop court ; le point principal manquait',
          'Bien, surtout la dernière page',
        ],
        'native': [
          'Je vois. Je mettrai le point principal en première page et je raccourcirai.',
          'J\'ajouterai des pages avec plus de détails.',
          'Merci ! J\'ai beaucoup travaillé la dernière page.',
        ],
        'why': [
          'Reçoit « trop long, l\'essentiel à la fin » tel que dit',
          'A entendu « trop long » comme « trop court »',
          'A entendu « personne ne l\'a lu » comme « c\'était bien »',
        ],
      },
      {
        'line': 'Bien. Et pour les directeurs, fais une version d\'une page. Ils n\'ont que cinq minutes pour la lire.',
        'gist': [
          'Une version d\'une page pour les directeurs ; ils ont cinq minutes',
          'Une version de cinq pages pour les directeurs ; ils ont tout leur temps',
          'Les directeurs n\'ont besoin de rien',
        ],
        'native': [
          'Une page pour les directeurs, compris. Je vous l\'envoie demain.',
          'Cinq pages pour les directeurs ? D\'accord, j\'écris plus.',
          'Donc les directeurs n\'ont pas besoin de copie. Compris.',
        ],
        'why': [
          'Reçoit « une page » tel que dit',
          'A entendu « une page, cinq minutes » comme « cinq pages »',
          'N\'a pas entendu « fais une version »',
        ],
      },
    ],
  },
  'builtin_t1': {
    'topic': 'Le pourboire',
    'setting': 'L\'addition arrive après le dîner au restaurant',
    'ex': [
      {
        'line': 'Voici l\'addition. Pour information, le pourboire n\'est pas inclus. La plupart des gens laissent environ 18 pour cent.',
        'gist': [
          'Le pourboire n\'est pas inclus ; 18 % est l\'usage',
          'Le pourboire est inclus ; rien à ajouter',
          'Pas de pourboire dans ce restaurant',
        ],
        'native': [
          'D\'accord, merci. J\'ajoute 18 pour cent.',
          'Ah, il est inclus ? Alors je paie juste ça.',
          'Pas de pourboire ici ? Super, merci.',
        ],
        'why': [
          'Reçoit « pas inclus, 18 % » tel que dit',
          'A entendu « pas inclus » comme « inclus »',
          'A entendu « laisser un pourboire » comme « pas de pourboire »',
        ],
      },
      {
        'line': 'Vous pouvez l\'ajouter sur le terminal de carte. Il vous demandera de choisir un pourcentage.',
        'gist': [
          'On l\'ajoute sur le terminal en choisissant un pourcentage',
          'On le laisse en espèces sur la table',
          'On le donne en main propre au serveur',
        ],
        'native': [
          'Parfait, je choisis 18 pour cent sur le terminal.',
          'Vous avez de la monnaie ? Je n\'ai que des gros billets.',
          'Tenez, c\'est pour vous.',
        ],
        'why': [
          'Reçoit « choisir sur le terminal » tel que dit',
          'A compris qu\'on paie en espèces',
          'A compris qu\'on le donne en main propre',
        ],
      },
    ],
  },
  'builtin_t2': {
    'topic': 'L\'eau est-elle gratuite ?',
    'setting': 'Vous venez de vous asseoir au restaurant',
    'ex': [
      {
        'line': 'Vous voulez de l\'eau ? L\'eau en bouteille coûte trois dollars, ou l\'eau du robinet est gratuite.',
        'gist': [
          'La bouteille coûte trois dollars ; l\'eau du robinet est gratuite',
          'Toute l\'eau est gratuite',
          'Toute l\'eau coûte trois dollars',
        ],
        'native': [
          'De l\'eau du robinet, s\'il vous plaît.',
          'De l\'eau en bouteille, s\'il vous plaît, puisque c\'est gratuit.',
          'Trois dollars pour de l\'eau du robinet ? Non merci.',
        ],
        'why': [
          'Reçoit « le robinet est gratuit » et choisit',
          'La gratuite, c\'est celle du robinet : mal entendu',
          'Les trois dollars, c\'est la bouteille : inversé',
        ],
      },
      {
        'line': 'Bien sûr. Et je vous préviens : la cuisine est un peu lente ce soir. Vos plats peuvent prendre environ trente minutes.',
        'gist': [
          'Les plats peuvent prendre environ trente minutes ce soir',
          'Ils ferment dans trente minutes, il faut se dépêcher',
          'Les plats arrivent en trois minutes',
        ],
        'native': [
          'Pas de souci, on n\'est pas pressés.',
          'Vous fermez dans trente minutes ? Alors on commande tout de suite.',
          'Seulement trois minutes ? Ouah, c\'est rapide.',
        ],
        'why': [
          'Reçoit « ça va prendre du temps » tel que dit',
          'A entendu « cuisine lente » comme « fermeture »',
          'A entendu trente comme trois',
        ],
      },
    ],
  },
  'builtin_t3': {
    'topic': 'Pas de réservation à l\'hôtel',
    'setting': 'À la réception, à l\'arrivée',
    'ex': [
      {
        'line': 'Je suis désolé, je ne trouve pas de réservation à votre nom pour ce soir. Ce serait peut-être pour demain ?',
        'gist': [
          'Pas de réservation trouvée pour ce soir ; demande si c\'est pour demain',
          'Il y a une réservation pour ce soir ; attendre la chambre',
          'Il y a une réservation pour demain, mais c\'est complet ce soir',
        ],
        'native': [
          'Ça devrait être pour ce soir. Voici mon e-mail de confirmation, vous pouvez vérifier le numéro de réservation ?',
          'D\'accord, j\'attends ici que la chambre soit prête.',
          'Complet ce soir ? Vous pouvez me conseiller un autre hôtel ?',
        ],
        'why': [
          'Répond à « introuvable, demain ? » avec une preuve',
          'A entendu « pas de réservation » comme « chambre en préparation »',
          'Personne n\'a dit « complet »',
        ],
      },
      {
        'line': 'Ah, je l\'ai trouvée. La réservation a été annulée parce que votre carte n\'a pas fonctionné. Il nous reste une chambre, mais le prix de ce soir est vingt dollars plus cher.',
        'gist': [
          'Annulée à cause de la carte ; une chambre reste, vingt dollars de plus',
          'Annulée à cause de la carte ; plus aucune chambre',
          'La réservation est valable ; même prix',
        ],
        'native': [
          'Ma carte n\'a pas fonctionné ? Personne ne m\'a prévenu. Je peux payer maintenant au prix d\'origine ?',
          'Plus de chambre ? Alors il me faut un autre hôtel.',
          'Même prix ? Super, je paie maintenant.',
        ],
        'why': [
          'Reçoit « annulée, une chambre reste, plus cher » et demande',
          'A entendu « il nous reste une chambre » comme « plus aucune »',
          'N\'a pas entendu « vingt dollars plus cher »',
        ],
      },
    ],
  },
  'builtin_t4': {
    'topic': 'Pas d\'eau chaude',
    'setting': 'La douche n\'a pas d\'eau chaude ; vous avez appelé la réception',
    'ex': [
      {
        'line': 'Je suis désolé pour l\'eau chaude. Je peux envoyer quelqu\'un la réparer dans environ trente minutes, ou je peux vous changer de chambre tout de suite.',
        'gist': [
          'Réparation dans trente minutes, ou changer de chambre tout de suite',
          'Réparation demain ; pas de changement de chambre possible',
          'Réparation tout de suite ; pas besoin de changer',
        ],
        'native': [
          'J\'attends la réparation, merci. Trente minutes, ça va.',
          'Demain ? C\'est trop tard. J\'ai besoin d\'eau chaude ce soir.',
          'Tout de suite ? Super, j\'attends près de la porte.',
        ],
        'why': [
          'Reçoit « réparation dans trente ou changement tout de suite » et choisit',
          'A entendu « trente minutes » comme « demain »',
          'Le « tout de suite », c\'était le changement de chambre, pas la réparation',
        ],
      },
      {
        'line': 'D\'accord. En attendant, vous pouvez utiliser la piscine sur le toit. Elle est ouverte jusqu\'à vingt-deux heures.',
        'gist': [
          'En attendant, la piscine du toit est ouverte jusqu\'à vingt-deux heures',
          'La piscine est fermée aujourd\'hui',
          'La piscine ouvre à vingt-deux heures',
        ],
        'native': [
          'Bonne idée, je vais à la piscine alors. Appelez ma chambre quand c\'est réparé.',
          'La piscine est fermée ? D\'accord, je reste dans la chambre.',
          'Elle ouvre à vingt-deux heures ? C\'est trop tard pour moi.',
        ],
        'why': [
          'Reçoit « ouverte jusqu\'à vingt-deux heures » tel que dit',
          'A entendu « ouverte » comme « fermée »',
          'A entendu « jusqu\'à » comme « à partir de »',
        ],
      },
    ],
  },
  'builtin_t5': {
    'topic': 'Le prix en caisse',
    'setting': 'En caisse avec un article affiché à −20 % en rayon',
    'ex': [
      {
        'line': 'Ça fait quarante-huit dollars cinquante. La remise de vingt pour cent est réservée aux membres, donc elle n\'est pas incluse.',
        'gist': [
          'Total 48,50 ; les 20 % sont réservés aux membres, pas inclus',
          'Total 48,50 ; les 20 % sont déjà déduits',
          'Total vingt dollars ; pas de remise',
        ],
        'native': [
          'Réservée aux membres ? Je peux devenir membre maintenant ?',
          'Ah, la remise est déduite ? D\'accord, voici ma carte.',
          'Vingt dollars ? Moins cher que je pensais.',
        ],
        'why': [
          'Reçoit « membres seulement, pas incluse » et agit',
          'A entendu « pas incluse » comme « incluse »',
          'A entendu « vingt pour cent » comme « vingt dollars »',
        ],
      },
      {
        'line': 'Oui, c\'est gratuit. J\'ai juste besoin de votre adresse e-mail. Ça prend une minute.',
        'gist': [
          'Devenir membre est gratuit ; juste un e-mail, une minute',
          'Devenir membre coûte de l\'argent et prend du temps',
          'Il faut une pièce d\'identité et ce n\'est pas possible aujourd\'hui',
        ],
        'native': [
          'D\'accord, allons-y. Mon e-mail, c\'est…',
          'Ça coûte de l\'argent ? Non merci.',
          'Je n\'ai pas ma pièce d\'identité. Laissez tomber.',
        ],
        'why': [
          'Reçoit « gratuit, e-mail, une minute » et continue',
          'A entendu « gratuit » comme « payant »',
          'Ce qu\'il faut, c\'est un e-mail : mal entendu',
        ],
      },
    ],
  },
};
