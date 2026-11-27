import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/backend_providers.dart';
import '../domain/prompt.dart';

/// Live stream of a single prompt (details screen).
final promptProvider = StreamProvider.family<Prompt?, String>(
  (ref, promptId) => ref.watch(promptRepositoryProvider).watchPrompt(promptId),
);

/// The single featured prompt (`is_featured == true`) for the home carousel.
final featuredPromptProvider = FutureProvider<Prompt?>(
  (ref) => ref.watch(promptRepositoryProvider).fetchFeatured(),
);
