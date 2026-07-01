import type { KnowledgeFile } from "../api/file";
import type { StorageProvider } from "@/types/storage";
import { isFileOnActiveStorage } from "../hooks/useActiveStorageType";

/** Formats we index and expose for OpenAI File Search in this platform. */
export const PLATFORM_FILE_SEARCH_EXTENSIONS = ["pdf", "docx", "txt"] as const;

/** Spreadsheet / data formats available when Code Interpreter is enabled. */
export const CODE_INTERPRETER_EXTENSIONS = ["csv", "xlsx", "xls", "tsv"] as const;

export type PlatformFileSearchExtension = (typeof PLATFORM_FILE_SEARCH_EXTENSIONS)[number];
export type CodeInterpreterExtension = (typeof CODE_INTERPRETER_EXTENSIONS)[number];

export function getFileExtension(fileName: string): string {
  const parts = fileName.split(".");
  if (parts.length < 2) {
    return "";
  }

  return (parts.pop() ?? "").toLowerCase();
}

export function getSelectableKnowledgeExtensions(
  fileSearchEnabled: boolean,
  codeInterpreterEnabled: boolean,
): string[] {
  const extensions = new Set<string>();

  if (fileSearchEnabled) {
    for (const extension of PLATFORM_FILE_SEARCH_EXTENSIONS) {
      extensions.add(extension);
    }
  }

  if (codeInterpreterEnabled) {
    for (const extension of CODE_INTERPRETER_EXTENSIONS) {
      extensions.add(extension);
    }
  }

  return [...extensions];
}

export function isKnowledgeFileSelectable(
  file: KnowledgeFile,
  activeStorageType: StorageProvider,
  fileSearchEnabled: boolean,
  codeInterpreterEnabled: boolean,
): boolean {
  if (!isFileOnActiveStorage(file.storageType, activeStorageType)) {
    return false;
  }

  if (!fileSearchEnabled && !codeInterpreterEnabled) {
    return false;
  }

  const extension = getFileExtension(file.name);
  const allowed = getSelectableKnowledgeExtensions(fileSearchEnabled, codeInterpreterEnabled);
  return allowed.includes(extension);
}

export function filterSelectableKnowledgeFileIds(
  fileIds: string[],
  files: KnowledgeFile[],
  activeStorageType: StorageProvider,
  fileSearchEnabled: boolean,
  codeInterpreterEnabled: boolean,
): string[] {
  const fileMap = new Map(files.map((file) => [file.id, file]));

  return fileIds.filter((fileId) => {
    const file = fileMap.get(fileId);
    if (!file) {
      return false;
    }

    return isKnowledgeFileSelectable(
      file,
      activeStorageType,
      fileSearchEnabled,
      codeInterpreterEnabled,
    );
  });
}
