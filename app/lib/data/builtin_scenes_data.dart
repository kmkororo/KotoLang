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

const _orders = [
  [0, 1, 2],
  [0, 2, 1],
  [1, 0, 2],
  [1, 2, 0],
  [2, 0, 1],
  [2, 1, 0],
];

/// The order the three choices are shown in for one question: a small
/// deterministic hash of where the question sits. The author's first item
/// (the right one) lands at `order.indexOf(0)`.
List<int> orderFor(String sceneId, int exchange, String question) {
  var h = 0;
  for (final c in '$sceneId/$exchange/$question'.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return _orders[h % _orders.length];
}

List<T> _arrange<T>(List<int> order, List<T> authored) =>
    [for (final k in order) authored[k]];

Map<String, dynamic> _merge(Map<String, dynamic> b, Map<String, dynamic> o) {
  final id = b['id'] as String;
  final bex = b['ex'] as List;
  final oex = (o['ex'] as List?) ?? const [];
  final exchanges = <Map<String, dynamic>>[];
  for (var i = 0; i < bex.length; i++) {
    final be = bex[i] as Map;
    final oe = i < oex.length ? oex[i] as Map : const {};
    final replies = (be['reply'] as List).cast<String>();
    final natives = ((oe['native'] as List?) ?? const []).cast<String>();
    final whys = ((oe['why'] as List?) ?? const []).cast<String>();
    final gists = ((oe['gist'] as List?) ?? const []).cast<String>();

    final gOrder = orderFor(id, i, 'gist');
    final rOrder = orderFor(id, i, 'reply');
    exchanges.add({
      'line': be['line'],
      'line_native': oe['line'] ?? '',
      'gist': {
        'options': gists.length == 3 ? _arrange(gOrder, gists) : gists,
        'answer': gOrder.indexOf(0),
      },
      'reply': {
        'options': _arrange(rOrder, [
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
    'exchanges': exchanges,
  };
}
