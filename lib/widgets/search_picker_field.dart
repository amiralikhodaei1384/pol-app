import 'package:flutter/material.dart';

/// Text field with a filtered option list that opens right under it as soon as it's focused.
///
/// The list is exactly as wide as the field, shows [maxVisibleItems] rows at a time and
/// scrolls for the rest. Picking a row calls [onSelected]; Enter calls [onSubmitted] with
/// whatever was typed, so free-text entries still work.
class SearchPickerField extends StatefulWidget {
  final TextEditingController controller;
  final List<String> options;

  /// Options already chosen; they're left out of the list.
  final List<String> exclude;
  final ValueChanged<String> onSelected;
  final ValueChanged<String>? onSubmitted;
  final InputDecoration decoration;
  final TextStyle? style;
  final int maxVisibleItems;

  /// Single-choice use (e.g. a university): close the list after a pick instead of keeping
  /// it open for the next one.
  final bool closeOnSelect;

  const SearchPickerField({
    super.key,
    required this.controller,
    required this.options,
    required this.onSelected,
    this.exclude = const [],
    this.onSubmitted,
    this.decoration = const InputDecoration(),
    this.style,
    this.maxVisibleItems = 4,
    this.closeOnSelect = false,
  });

  @override
  State<SearchPickerField> createState() => _SearchPickerFieldState();
}

class _SearchPickerFieldState extends State<SearchPickerField> {
  static const double _itemHeight = 42;

  final _link = LayerLink();
  final _overlay = OverlayPortalController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  double _fieldWidth = 0;

  // Whether the list was open when the current tap began. The tap itself can change focus,
  // so this has to be read on pointer-down, before anything else reacts.
  bool _openAtPointerDown = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_syncOverlay);
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(SearchPickerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _syncOverlay() {
    if (_focusNode.hasFocus) {
      _overlay.show();
    } else {
      _overlay.hide();
    }
  }

  void _onTextChanged() {
    // Rebuild the list (and the clear button) as the query changes; new results start at the top.
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    if (!mounted) return;
    setState(() {});
    // Typing brings the list back if a tap on the field had closed it.
    if (_focusNode.hasFocus && !_overlay.isShowing) _overlay.show();
  }

  // Tapping the field toggles the list: an open list closes, a closed one opens.
  void _onFieldTap() {
    if (_openAtPointerDown) {
      _overlay.hide();
    } else {
      _overlay.show();
    }
  }

  List<String> get _matches {
    final query = widget.controller.text.trim().toLowerCase();
    final available = widget.options.where((o) => !widget.exclude.contains(o));
    // When the field already holds a chosen option (single-choice use), reopening it
    // shows the whole list so another option can be picked, not just the current one.
    if (query.isEmpty || available.any((o) => o.toLowerCase() == query)) return available.toList();
    return available.where((o) => o.toLowerCase().contains(query)).toList();
  }

  void _pick(String option) {
    widget.onSelected(option);
    if (widget.closeOnSelect) {
      _focusNode.unfocus();
    } else {
      // Keep focus so several items can be added in a row.
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _fieldWidth = constraints.maxWidth;
        return CompositedTransformTarget(
          link: _link,
          child: OverlayPortal(
            controller: _overlay,
            overlayChildBuilder: _buildList,
            child: Listener(
              onPointerDown: (_) => _openAtPointerDown = _overlay.isShowing,
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                onTap: _onFieldTap,
                // Flutter only unfocuses on outside taps on web/desktop; do it on phones too so the
                // list never stays open over the rest of the form. Taps on the list don't count
                // (it's wrapped in TextFieldTapRegion).
                onTapOutside: (_) => _focusNode.unfocus(),
                style: widget.style,
                onSubmitted: (value) {
                  widget.onSubmitted?.call(value);
                  _focusNode.requestFocus();
                },
                decoration: widget.decoration.copyWith(
                  suffixIcon: widget.controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: widget.controller.clear,
                        )
                      : const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF94A3B8)),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildList(BuildContext context) {
    final matches = _matches;
    final query = widget.controller.text.trim();
    if (matches.isEmpty && query.isEmpty) return const SizedBox.shrink();

    final visibleRows = matches.isEmpty ? 1 : matches.length.clamp(1, widget.maxVisibleItems);

    return Positioned(
      width: _fieldWidth,
      child: CompositedTransformFollower(
        link: _link,
        showWhenUnlinked: false,
        // Under the field, flush with both of its edges.
        targetAnchor: Alignment.bottomLeft,
        followerAnchor: Alignment.topLeft,
        offset: const Offset(0, 4),
        // Taps on the list count as taps on the field, so it doesn't lose focus and close first.
        child: TextFieldTapRegion(
          child: Directionality(
            textDirection: Directionality.of(this.context),
            child: Material(
              elevation: 6,
              color: Colors.white,
              shadowColor: Colors.black26,
              borderRadius: BorderRadius.circular(10),
              clipBehavior: Clip.antiAlias,
              child: Container(
                height: visibleRows * _itemHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF1E6AFB)),
                ),
                child: matches.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            widget.onSubmitted != null ? 'موردی یافت نشد؛ برای افزودن «$query» Enter بزنید.' : 'موردی یافت نشد.',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ),
                      )
                    : Scrollbar(
                        controller: _scrollController,
                        thumbVisibility: matches.length > widget.maxVisibleItems,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: EdgeInsets.zero,
                          itemExtent: _itemHeight,
                          itemCount: matches.length,
                          itemBuilder: (context, index) {
                            final option = matches[index];
                            return InkWell(
                              onTap: () => _pick(option),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        option,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
                                      ),
                                    ),
                                    const Icon(Icons.add_circle_outline, size: 16, color: Color(0xFF10B981)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
