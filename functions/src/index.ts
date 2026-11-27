/**
 * PromptIndo — Cloud Functions entry point.
 *
 * Section 3 (counters / trending / notifications), Section 5 (auth
 * provisioning) and Section 7 (every callable behind a tappable action) of the
 * build spec are all exported from here.
 */

// Auth ------------------------------------------------------------- Section 5
export { onUserCreate, onUserDelete, ensureUserProfile } from "./triggers/auth";

// Counters + notifications ----------------------------------------- Section 3
export {
  onLikeCreate,
  onLikeDelete,
  onCommentLikeCreate,
  onCommentLikeDelete,
  onBookmarkCreate,
  onBookmarkDelete,
} from "./triggers/likes";
export { onCommentCreate, onCommentDelete } from "./triggers/comments";
export { onFollowCreate, onFollowDelete } from "./triggers/follows";
export { onPromptCreate, onPromptDelete } from "./triggers/prompts";
export { onReportCreate } from "./triggers/reports";

// Callables --------------------------------------------------------- Section 3 & 7
export { copyPrompt, recordView } from "./callables/social";
export { deleteUserAccount } from "./callables/account";
export {
  adminSetUserStatus,
  adminSetRole,
  adminSetPromptStatus,
  adminSetPromptFeatured,
  adminDeletePrompt,
  adminDeleteComment,
  adminResolveReport,
  adminSaveCategory,
  adminDeleteCategory,
} from "./callables/admin";

// Scheduled --------------------------------------------------------- Section 3
export { recomputeTrending, cleanupViews } from "./scheduled/trending";
