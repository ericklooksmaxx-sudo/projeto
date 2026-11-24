import 'package:material_ui/material_ui.dart';
import 'package:kyzen/l10n/context_extensions.dart';

class FaqView extends StatefulWidget {
  const FaqView({super.key});

  @override
  State<FaqView> createState() => _FaqViewState();
}

class _FaqViewState extends State<FaqView> {
  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> faqItems = [
      {
        "question": context.l10n.faqQuestionUnavailable,
        "icon": Icons.block_rounded,
        "answerWidget": Builder(
          builder: (context) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.block_rounded,
                    size: 18,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      context.l10n.faqUnavailableDescription,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      context.l10n.faqNoOverlayDescription,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.faqAnswer9ExtraInfo,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      },
      {
        "question": context.l10n.faqQuestion1,
        "answer": context.l10n.faqAnswer1,
        "icon": Icons.key_rounded,
      },
      {
        "question": context.l10n.faqQuestion6,
        "answer": context.l10n.faqAnswer6,
        "iconAsset": "assets/persona.png",
      },
      {
        "question": context.l10n.faqQuestion7,
        "answer": context.l10n.faqAnswer7,
        "iconAsset": "assets/skin.png",
      },
      {
        "question": context.l10n.faqQuestion8,
        "answer": context.l10n.faqAnswer8,
        "icon": Icons.account_circle_rounded,
      },
      {
        "question": context.l10n.faqQuestion2,
        "answer": context.l10n.faqAnswer2,
        "icon": Icons.update,
      },
      {
        "question": context.l10n.faqQuestion3,
        "answer": context.l10n.faqAnswer3,
        "icon": Icons.security,
      },
      {
        "question": context.l10n.faqQuestion4,
        "answer": context.l10n.faqAnswer4,
        "icon": Icons.folder,
      },
      {
        "question": context.l10n.faqQuestion5,
        "answer": context.l10n.faqAnswer5,
        "icon": Icons.file_present,
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.faqUppercase),
        forceMaterialTransparency: true,
      ),
      body: ListView.builder(
        padding: EdgeInsets.fromLTRB(
          12.0,
          12.0,
          12.0,
          12.0 + MediaQuery.paddingOf(context).bottom,
        ),
        itemCount: faqItems.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10.0),
            child: FaqCard(
              question: faqItems[index]["question"],
              answer: faqItems[index]["answer"] ?? '',
              icon: faqItems[index]["icon"],
              iconAsset: faqItems[index]["iconAsset"],
              answerWidget: faqItems[index]["answerWidget"],
            ),
          );
        },
      ),
    );
  }
}

class FaqCard extends StatefulWidget {
  final String question;
  final String answer;
  final Widget? answerWidget;
  final IconData? icon;
  final String? iconAsset;

  const FaqCard({
    super.key,
    required this.question,
    required this.answer,
    this.answerWidget,
    this.icon,
    this.iconAsset,
  });

  @override
  State<FaqCard> createState() => _FaqCardState();
}

class _FaqCardState extends State<FaqCard> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  Widget _buildIcon() {
    if (widget.iconAsset != null) {
      return Image.asset(
        widget.iconAsset!,
        width: 24,
        height: 24,
        color: Theme.of(context).colorScheme.primary,
      );
    } else if (widget.icon != null) {
      return Icon(
        widget.icon,
        color: Theme.of(context).colorScheme.primary,
        size: 24,
      );
    } else {
      return Icon(
        Icons.help_outline,
        color: Theme.of(context).colorScheme.primary,
        size: 24,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Column(
        children: [
          InkWell(
            onTap: _toggleExpanded,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Row(
                children: [
                  _buildIcon(),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.question,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(4, 0, 8, 4),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child:
                    widget.answerWidget ??
                    Text(
                      widget.answer,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
