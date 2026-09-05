/// The built-in scenes as data, assembled per interface language.
///
/// The English — the spoken line and the three replies — lives once, in
/// `scenes/base.dart`. Each language adds an overlay: the setting, the
/// translation of the line, the three gists, and the translation and reason
/// for each reply. A scene only exists in a language that has written it.
///
/// Ids are fixed across languages ("builtin_w1" is the same scene in every
/// language), because results and reviews are keyed by them. Every author
/// writes the right answer first; the position it ends up in is decided here,
/// from the id, so it is spread across the choices and identical in every
/// language.
library;

import '../domain/scene.dart';
import 'scenes/base.dart';
import 'scenes/de.dart';
import 'scenes/en.dart';
import 'scenes/es.dart';
import 'scenes/fr.dart';
import 'scenes/hi.dart';
import 'scenes/id.dart';
import 'scenes/ja.dart';
import 'scenes/ko.dart';
import 'scenes/pt_br.dart';
import 'scenes/zh_cn.dart';

const Map<String, Map<String, Map<String, dynamic>>> _overlays = {
  'en': en,
  'ja': ja,
  'es': es,
  'pt-BR': ptBr,
  'fr': fr,
  'de': de,
  'ko': ko,
  'zh-CN': zhCn,
  'hi': hi,
  'id': id,
};

/// Which kind of life a built-in scene belongs to — 'work', 'travel',
/// 'school', 'daily' — by its id prefix.
String kindOf(String id) {
  if (id.startsWith('builtin_w')) return 'work';
  if (id.startsWith('builtin_t')) return 'travel';
  if (id.startsWith('builtin_s')) return 'school';
  if (id.startsWith('builtin_d')) return 'daily';
  return '';
}

/// The scenes written in [lang], in the payload shape the importer reads.
/// A language with no overlay gets the English set.
List<Map<String, dynamic>> scenesFor(String lang) {
  final overlay = _overlays[lang] ?? _overlays['en']!;
  return [
    for (final b in base)
      if (overlay[b['id']] != null) _merge(b, overlay[b['id']]!),
  ];
}

Map<String, dynamic> _merge(Map<String, dynamic> b, Map<String, dynamic> o) {
  final id = b['id'] as String;
  final bex = b['ex'] as List;
  final oex = (o['ex'] as List?) ?? const [];
  // The English of the gist question lives in the English overlay; every
  // other overlay carries the translation of the same three summaries.
  final eex = (en[id]?['ex'] as List?) ?? const [];
  final translated = !identical(o, en[id]);
  final exchanges = <Map<String, dynamic>>[];
  for (var i = 0; i < bex.length; i++) {
    final be = bex[i] as Map;
    final oe = i < oex.length ? oex[i] as Map : const {};
    final ee = i < eex.length ? eex[i] as Map : const {};
    final replies = (be['reply'] as List).cast<String>();
    final natives = ((oe['native'] as List?) ?? const []).cast<String>();
    final whys = ((oe['why'] as List?) ?? const []).cast<String>();
    final gists = ((ee['gist'] as List?) ?? const []).cast<String>();
    final gistNatives = translated ? ((oe['gist'] as List?) ?? const []).cast<String>() : const <String>[];

    final gOrder = optionOrder(id, i, 'gist');
    final rOrder = optionOrder(id, i, 'reply');
    exchanges.add({
      'line': be['line'],
      'line_native': oe['line'] ?? '',
      'gist': {
        'options': [
          for (var k = 0; k < gOrder.length; k++)
            {
              'text': gists.length == 3 ? gists[gOrder[k]] : '',
              'native': gistNatives.length == 3 ? gistNatives[gOrder[k]] : '',
            }
        ],
        'answer': gOrder.indexOf(0),
      },
      'reply': {
        'options': arrangeBy(rOrder, [
          for (var k = 0; k < replies.length; k++)
            {
              'text': replies[k],
              'native': k < natives.length ? natives[k] : '',
              'why': k < whys.length ? whys[k] : '',
            }
        ]),
        'answer': rOrder.indexOf(0),
      },
    });
  }
  return {
    'id': id,
    'topic': b['topic'],
    'topic_native': o['topic'] ?? '',
    'setting_native': o['setting'] ?? '',
    'source': 'builtin',
    'realm_id': kindOf(id),
    'exchanges': exchanges,
  };
}
