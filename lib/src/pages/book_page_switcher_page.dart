import 'dart:math' as math;

import 'package:book_page_switcher_demo/src/widgets/hs_book_page_switcher.dart';
import 'package:flutter/material.dart';

class BookPageSwitcherPage extends StatefulWidget {
  const BookPageSwitcherPage({super.key});

  @override
  State<BookPageSwitcherPage> createState() => _BookPageSwitcherPageState();
}

class _BookPageSwitcherPageState extends State<BookPageSwitcherPage> {
  final HsBookPageController _controller = HsBookPageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<_ReaderPageData> pageData = <_ReaderPageData>[
      const _ReaderPageData(
        chapter: '第一章',
        eyebrow: '卷页阅读',
        title: '纸页从右下角被慢慢掀起',
        quote: '当一页纸真的被掀开时，最先发生变化的不是角度，而是边缘的重量。',
        paragraphs: <String>[
          '这一版示例不再把页面当作展示卡片，而是把它放回阅读器场景里。正文留白、页边距离、段落密度、页码信息和底色都按“长时间阅读”去处理，翻页动作才会显得自然。',
          '你可以按住右下角慢慢拖动，卷页的受光、底页投影和纸背色会一点点出现。它不是为了夸张地展示 3D，而是为了让人相信下面真的压着另一页。',
        ],
        footerLeft: '阅读剩余 3 分钟',
        footerRight: '01',
        accentColor: Color(0xFF83624B),
      ),
      const _ReaderPageData(
        chapter: '第二章',
        eyebrow: '跟手阻尼',
        title: '越接近完成态，卷页越有一点阻尼',
        quote: '手指抬起以后，纸页还会沿着刚才的轨迹自己走完一小段。',
        paragraphs: <String>[
          '为了更接近微信读书的默认仿真翻页，拖拽前段会更跟手，越靠近完成态，进度压缩越明显。这样页面不会突然冲到尽头，而是像纸张有一点张力。',
          '程序触发翻页和手势翻页也被区分开了。按钮切页会更平滑、规整；手势翻页则会保留最后一次拖拽时的卷角位置，所以松手收尾看起来更像顺势翻过去。',
        ],
        footerLeft: '亮度 68% · 仿真翻页',
        footerRight: '02',
        accentColor: Color(0xFF6B5844),
      ),
      const _ReaderPageData(
        chapter: '第三章',
        eyebrow: '暖纸质感',
        title: '纸背、卷痕和页边都回到了阅读器的暖色语境',
        quote: '真正让人相信“这是一页纸”的，往往是那些几乎注意不到的细节。',
        paragraphs: <String>[
          '示例页里用了更接近阅读器的米白底色、暖灰阴影和很轻的纸张纹理。卷页背面不再是纯白高光，而是像灯光扫过纸纤维时的柔和反射。',
          '如果你需要把这个组件接进小说、故事型活动或作品集引导页，这套示例会比之前的渐变卡片更接近真实使用方式，也更容易看出卷页动画本身的质感。',
        ],
        footerLeft: '可用于小说、故事页、说明页',
        footerRight: '03',
        accentColor: Color(0xFF8A6849),
      ),
    ];
    final List<Widget> pages = pageData
        .map(
          (_ReaderPageData data) => _ReaderDemoPage(
            data: data,
            pageIndex: pageData.indexOf(data),
            pageCount: pageData.length,
          ),
        )
        .toList(growable: false);

    return Scaffold(
      backgroundColor: const Color(0xFFE3DACB),
      appBar: AppBar(
        title: const Text('仿真卷页阅读器'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.34),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '阅读器演示',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: Color(0xFF7B624E),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '示例页已经改成更接近微信读书的正文场景：暖灰背景、米白纸页、页码信息和较长的正文段落，方便观察卷页时的纸感和底页投影。',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.7,
                    color: Color(0xFF4B3E33),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const [
                    _ReadingMetaChip(label: '右下角拖拽'),
                    _ReadingMetaChip(label: '底页投影'),
                    _ReadingMetaChip(label: '暖纸纹理'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFB9AC97).withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(30),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x261F1813),
                  blurRadius: 26,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            child: AspectRatio(
              aspectRatio: 0.76,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(26),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFF0E6D7), Color(0xFFE2D5C1)],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: HsBookPageSwitcher(
                      controller: _controller,
                      enableLoop: true,
                      duration: const Duration(milliseconds: 560),
                      paperBackColor: const Color(0xFFF3EADC),
                      shadowColor: const Color(0x332A1F16),
                      onPageChanged: (int index) {
                        setState(() {
                          _currentPage = index;
                        });
                      },
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F0E4),
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: const Color(
                            0xFFFDF9F1,
                          ).withValues(alpha: 0.72),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x241C140F),
                            blurRadius: 18,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      children: pages,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF6EFE4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE6DCCB)),
            ),
            child: const Text(
              '建议体验方式：按住右下角向左上慢慢拖，观察卷页边缘的厚度、底页上的细投影和纸背纹理；再用下方按钮切页，对比程序翻页和手势翻页的收尾感。',
              style: TextStyle(
                fontSize: 13.5,
                height: 1.75,
                color: Color(0xFF5A493A),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(pages.length, (int index) {
              final bool isActive = _currentPage == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: isActive ? 30 : 9,
                height: 9,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFF6B5645)
                      : const Color(0xFFB8A894),
                  borderRadius: BorderRadius.circular(999),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _controller.previousPage,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF5D493A),
                    side: const BorderSide(color: Color(0xFFB9A78F)),
                    backgroundColor: const Color(0xFFF8F2E8),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.chevron_left_rounded),
                  label: const Text('上一页'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _controller.nextPage,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6C5644),
                    foregroundColor: const Color(0xFFFFFAF3),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.chevron_right_rounded),
                  label: const Text('下一页'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(pageData.length, (int index) {
              final bool isActive = _currentPage == index;
              return ChoiceChip(
                label: Text('第 ${index + 1} 页'),
                selected: isActive,
                selectedColor: const Color(0xFFE8DCCB),
                labelStyle: TextStyle(
                  color: isActive
                      ? const Color(0xFF5B4838)
                      : const Color(0xFF715C4A),
                ),
                onSelected: (_) {
                  _controller.animateToPage(index);
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _ReaderDemoPage extends StatelessWidget {
  const _ReaderDemoPage({
    required this.data,
    required this.pageIndex,
    required this.pageCount,
  });

  final _ReaderPageData data;
  final int pageIndex;
  final int pageCount;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 336;
        final double maxHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 560;
        final double heightScale = (maxHeight / 560)
            .clamp(0.58, 1.0)
            .toDouble();
        final double widthScale = (maxWidth / 336).clamp(0.78, 1.0).toDouble();
        final double pageScale = math.min(heightScale, widthScale);
        double scaled(double value) => value * pageScale;
        final double titleFontSize = scaled(pageScale < 0.72 ? 25 : 28);
        final double quoteFontSize = scaled(pageScale < 0.72 ? 12.5 : 14);
        final double bodyFontSize = scaled(pageScale < 0.72 ? 13.5 : 15);
        final double bodyHeight = pageScale < 0.72 ? 1.72 : 1.9;
        final double quoteHeight = pageScale < 0.72 ? 1.62 : 1.75;

        return Container(
          padding: EdgeInsets.fromLTRB(
            scaled(26),
            scaled(26),
            scaled(26),
            scaled(22),
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(scaled(26)),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFFCF6), Color(0xFFF7F0E4)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    data.chapter,
                    style: TextStyle(
                      fontSize: scaled(12),
                      fontWeight: FontWeight.w700,
                      letterSpacing: scaled(1.2),
                      color: data.accentColor,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${pageIndex + 1} / $pageCount',
                    style: TextStyle(
                      fontSize: scaled(12),
                      color: const Color(0xFF9B8A77),
                    ),
                  ),
                ],
              ),
              SizedBox(height: scaled(16)),
              Text(
                data.eyebrow,
                style: TextStyle(
                  fontSize: scaled(12.5),
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFA1886F),
                ),
              ),
              SizedBox(height: scaled(10)),
              Text(
                data.title,
                style: TextStyle(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.w800,
                  height: pageScale < 0.72 ? 1.22 : 1.28,
                  color: const Color(0xFF2E241C),
                ),
              ),
              SizedBox(height: scaled(16)),
              Container(
                padding: EdgeInsets.fromLTRB(
                  scaled(14),
                  scaled(12),
                  scaled(14),
                  scaled(12),
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(scaled(16)),
                  border: Border.all(color: const Color(0xFFE7DCCB)),
                ),
                child: Text(
                  data.quote,
                  style: TextStyle(
                    fontSize: quoteFontSize,
                    height: quoteHeight,
                    color: const Color(0xFF665241),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              SizedBox(height: scaled(16)),
              ...data.paragraphs.map(
                (String paragraph) => Padding(
                  padding: EdgeInsets.only(bottom: scaled(10)),
                  child: Text(
                    paragraph,
                    style: TextStyle(
                      fontSize: bodyFontSize,
                      height: bodyHeight,
                      color: const Color(0xFF45372C),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Container(height: 1, color: const Color(0xFFE0D3C1)),
              SizedBox(height: scaled(10)),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      data.footerLeft,
                      style: TextStyle(
                        fontSize: scaled(11.5),
                        color: const Color(0xFF937F6B),
                      ),
                    ),
                  ),
                  Text(
                    data.footerRight,
                    style: TextStyle(
                      fontSize: scaled(13),
                      fontWeight: FontWeight.w700,
                      color: data.accentColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ReadingMetaChip extends StatelessWidget {
  const _ReadingMetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF755E4A),
        ),
      ),
    );
  }
}

class _ReaderPageData {
  const _ReaderPageData({
    required this.chapter,
    required this.eyebrow,
    required this.title,
    required this.quote,
    required this.paragraphs,
    required this.footerLeft,
    required this.footerRight,
    required this.accentColor,
  });

  final String chapter;
  final String eyebrow;
  final String title;
  final String quote;
  final List<String> paragraphs;
  final String footerLeft;
  final String footerRight;
  final Color accentColor;
}
