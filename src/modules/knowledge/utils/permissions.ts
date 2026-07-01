import type { KnowledgeFile, KnowledgeFolder, SharedUser } from "../api/file";

export function isOwner(
  item: Pick<KnowledgeFolder | KnowledgeFile, "userId">,
  userId?: string,
): boolean {
  return Boolean(userId && item.userId === userId);
}

export function getSharedEntry(
  item: Pick<KnowledgeFolder | KnowledgeFile, "sharedWith">,
  userId?: string,
): SharedUser | undefined {
  if (!userId) {
    return undefined;
  }

  return item.sharedWith.find((entry) => entry.id === userId && !entry.excluded);
}

export function hasWriteAccess(
  item: Pick<KnowledgeFolder | KnowledgeFile, "userId" | "sharedWith">,
  userId?: string,
): boolean {
  if (isOwner(item, userId)) {
    return true;
  }

  return getSharedEntry(item, userId)?.permissions === "write";
}

export function canManageItem(
  item: Pick<KnowledgeFolder | KnowledgeFile, "userId" | "sharedWith">,
  userId?: string,
): boolean {
  return hasWriteAccess(item, userId);
}

export function isSharedWithMe(
  item: Pick<KnowledgeFolder | KnowledgeFile, "userId" | "sharedWith">,
  userId?: string,
): boolean {
  return Boolean(userId && item.userId !== userId && getSharedEntry(item, userId));
}
