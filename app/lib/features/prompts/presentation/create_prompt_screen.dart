import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animation/app_curves.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/providers/backend_providers.dart';
import '../../../core/services/image_picker_helper.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/glass_input.dart';
import '../../../core/widgets/glass_sheets.dart';
import '../../../core/widgets/glass_toast.dart';
import '../../../core/widgets/spring_press.dart';
import '../../categories/domain/category.dart';
import '../../categories/presentation/category_providers.dart';
import '../domain/prompt.dart';

/// Publish (and edit-free v1: create only) a prompt.
///
/// Order of operations matches the rules: upload the thumbnail under
/// `thumbnails/{uid}/…` first (Storage validates type + 8MB), then `add` the
/// `prompts` doc with all counters at zero and `creator_*` fields filled from
/// the signed-in profile — exactly the shape `firestore.rules` allows.
class CreatePromptScreen extends ConsumerStatefulWidget {
  const CreatePromptScreen({super.key, this.editingId});

  final String? editingId;

  @override
  ConsumerState<CreatePromptScreen> createState() => _CreatePromptScreenState();
}

class _CreatePromptScreenState extends ConsumerState<CreatePromptScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _content = TextEditingController();
  final _tags = TextEditingController();
  final _aiModel = TextEditingController(text: 'GPT-4o');

  Category? _category;
  PromptVisibility _visibility = PromptVisibility.public;
  CompressedImage? _image;
  bool _busy = false;
  int _failedAttempts = 0;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _content.dispose();
    _tags.dispose();
    _aiModel.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final source = await showGlassActionSheet<ImageSourcePair>(
      context,
      title: 'Thumbnail',
      actions: const [
        GlassSheetAction(label: 'Take a photo', value: ImageSourcePair.camera),
        GlassSheetAction(
          label: 'Choose from library',
          value: ImageSourcePair.gallery,
        ),
      ],
    );
    if (source == null) return;

    final picked = await pickAndCompress(
      fromCamera: source == ImageSourcePair.camera,
    );
    if (picked != null) setState(() => _image = picked);
  }

  Future<void> _publish() async {
    FocusScope.of(context).unfocus();
    if (_title.text.trim().isEmpty || _content.text.trim().isEmpty) {
      setState(() => _failedAttempts++);
      GlassToast.show(
        context,
        'Title and prompt text are required',
        icon: Icons.error_outline_rounded,
      );
      return;
    }
    if (_category == null) {
      setState(() => _failedAttempts++);
      GlassToast.show(
        context,
        'Pick a category',
        icon: Icons.error_outline_rounded,
      );
      return;
    }

    final uid = ref.read(currentUidProvider);
    if (uid == null) return;

    setState(() => _busy = true);
    try {
      final profile = await ref.read(userRepositoryProvider).getUser(uid);

      String thumbnailUrl = '';
      String thumbnailPath = '';
      if (_image != null) {
        final uploaded = await ref
            .read(promptRepositoryProvider)
            .uploadThumbnail(
              uid: uid,
              bytes: _image!.bytes,
              fileName: _image!.fileName,
              contentType: _image!.contentType,
            );
        thumbnailPath = uploaded.path;
        thumbnailUrl = uploaded.url;
      }

      final prompt = Prompt(
        id: '',
        title: _title.text.trim(),
        description: _description.text.trim(),
        promptContent: _content.text.trim(),
        categoryId: _category!.id,
        tags: _tags.text
            .split(',')
            .map((tag) => tag.trim().toLowerCase())
            .where((tag) => tag.isNotEmpty)
            .take(8)
            .toList(),
        aiModel: _aiModel.text.trim(),
        visibility: _visibility,
        status: 'active',
        creatorId: uid,
        creatorUsername: profile?.username ?? '',
        creatorAvatar: profile?.avatarUrl ?? '',
        thumbnailUrl: thumbnailUrl,
        thumbnailPath: thumbnailPath,
        likeCount: 0,
        copyCount: 0,
        viewCount: 0,
        commentCount: 0,
        bookmarkCount: 0,
        isFeatured: false,
        trendScore: 0,
        remixedFromId: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final id = await ref.read(promptRepositoryProvider).createPrompt(prompt);
      if (!mounted) return;
      GlassToast.show(context, 'Published');
      Navigator.of(context).pop(id);
    } catch (e) {
      if (mounted) {
        setState(() => _failedAttempts++);
        GlassToast.show(
          context,
          'Could not publish — check your connection',
          icon: Icons.error_outline_rounded,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.screen),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GlassHeader(title: 'New prompt', padding: EdgeInsets.zero),
              const SizedBox(height: AppSpace.lg),
              // Thumbnail picker.
              SpringPress(
                onTap: _pickImage,
                child: GlassContainer(
                  height: 150,
                  alignment: Alignment.center,
                  child: _image == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 28,
                              color: t.textPrimary,
                            ),
                            const SizedBox(height: AppSpace.sm),
                            Text(
                              'Add thumbnail (optional)',
                              style: t.onGlass(AppType.caption()),
                            ),
                          ],
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.memory(
                            _image!.bytes,
                            width: double.infinity,
                            height: 150,
                            fit: BoxFit.cover,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              GlassInput(
                controller: _title,
                label: 'TITLE',
                hint: 'e.g. Cold-email opener that gets replies',
                maxLength: 80,
              ),
              const SizedBox(height: AppSpace.md),
              GlassInput(
                controller: _description,
                label: 'DESCRIPTION',
                hint: 'What it does and when to use it',
                minLines: 2,
                maxLines: 4,
                maxLength: 280,
              ),
              const SizedBox(height: AppSpace.md),
              GlassInput(
                controller: _content,
                label: 'PROMPT',
                hint: 'Write the full prompt here…',
                minLines: 6,
                maxLines: 14,
              ),
              const SizedBox(height: AppSpace.md),
              // Category picker.
              Text('CATEGORY', style: t.onGlass(AppType.micro())),
              const SizedBox(height: AppSpace.xs),
              GlassContainer(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.lg,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _category == null
                            ? 'Select a category'
                            : '${_category!.icon}  ${_category!.name}',
                        style: _category == null
                            ? t.onGlassMuted(AppType.body())
                            : t.onGlass(AppType.body()),
                      ),
                    ),
                    Icon(Icons.expand_more_rounded, color: t.textSecondary),
                  ],
                ),
              ),
              if (_category == null && _failedAttempts > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 4),
                  child: Text(
                    'Pick a category',
                    style: AppType.caption(color: const Color(0xFFFF3B30)),
                  ),
                ),
              if (categories.value != null && categories.value!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpace.sm),
                  child: Wrap(
                    spacing: AppSpace.sm,
                    runSpacing: AppSpace.sm,
                    children: [
                      for (final category in categories.value!)
                        SpringPress(
                          onTap: () => setState(() => _category = category),
                          child: AnimatedContainer(
                            duration: AppMotion.themeFade,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: _category?.id == category.id
                                  ? const Color(0xE6FFFFFF)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(1000),
                              border: Border.all(
                                color: t.borderStrong,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              '${category.icon} ${category.name}',
                              style: t.onGlass(AppType.caption()),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpace.lg),
              GlassInput(
                controller: _tags,
                label: 'TAGS',
                hint: 'marketing, email, gpt-4o (comma separated)',
              ),
              const SizedBox(height: AppSpace.md),
              GlassInput(
                controller: _aiModel,
                label: 'AI MODEL',
                hint: 'GPT-4o',
              ),
              const SizedBox(height: AppSpace.lg),
              Text('VISIBILITY', style: t.onGlass(AppType.micro())),
              const SizedBox(height: AppSpace.xs),
              Row(
                children: [
                  for (final value in PromptVisibility.values)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: AppSpace.sm),
                        child: SpringPress(
                          onTap: () => setState(() => _visibility = value),
                          child: AnimatedContainer(
                            duration: AppMotion.themeFade,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _visibility == value
                                  ? const Color(0xE6FFFFFF)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(1000),
                              border: Border.all(
                                color: t.borderStrong,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              value.name[0].toUpperCase() +
                                  value.name.substring(1),
                              textAlign: TextAlign.center,
                              style: t.onGlass(AppType.button()),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpace.xl),
              GlassButton(
                label: 'Publish',
                expand: true,
                loading: _busy,
                onPressed: _busy ? null : _publish,
              ),
              const SizedBox(height: AppSpace.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

enum ImageSourcePair { camera, gallery }
