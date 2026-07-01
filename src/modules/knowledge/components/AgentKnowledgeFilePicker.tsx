import { useEffect, useMemo } from "react";
import { AlertCircle, FileText } from "lucide-react";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import { KnowledgeFilePicker } from "./KnowledgeFilePicker";
import {
  CODE_INTERPRETER_EXTENSIONS,
  PLATFORM_FILE_SEARCH_EXTENSIONS,
  filterSelectableKnowledgeFileIds,
  getSelectableKnowledgeExtensions,
  isKnowledgeFileSelectable,
} from "../utils/agentKnowledgeFileTypes";
import { useActiveStorageType, STORAGE_PROVIDER_LABELS } from "../hooks/useActiveStorageType";
import { listSelectableKnowledgeFiles } from "../api/file";
import { useQuery } from "@tanstack/react-query";

interface AgentKnowledgeFilePickerProps {
  selectedFileIds: string[];
  onChange: (fileIds: string[]) => void;
  fileSearchEnabled: boolean;
  codeInterpreterEnabled: boolean;
  disabled?: boolean;
}

export function AgentKnowledgeFilePicker({
  selectedFileIds,
  onChange,
  fileSearchEnabled,
  codeInterpreterEnabled,
  disabled = false,
}: AgentKnowledgeFilePickerProps): JSX.Element {
  const activeStorageQuery = useActiveStorageType();
  const activeStorageType = activeStorageQuery.data?.storageType ?? "local";

  const filesQuery = useQuery({
    queryKey: ["knowledge", "file-picker", "files"],
    queryFn: listSelectableKnowledgeFiles,
  });

  const allFiles = useMemo(() => filesQuery.data ?? [], [filesQuery.data]);

  const visibleFiles = useMemo(
    () =>
      allFiles.filter((file) =>
        isKnowledgeFileSelectable(
          file,
          activeStorageType,
          fileSearchEnabled,
          codeInterpreterEnabled,
        ),
      ),
    [activeStorageType, allFiles, codeInterpreterEnabled, fileSearchEnabled],
  );

  const allowedExtensions = getSelectableKnowledgeExtensions(
    fileSearchEnabled,
    codeInterpreterEnabled,
  );

  useEffect(() => {
    const pruned = filterSelectableKnowledgeFileIds(
      selectedFileIds,
      allFiles,
      activeStorageType,
      fileSearchEnabled,
      codeInterpreterEnabled,
    );

    if (pruned.length !== selectedFileIds.length) {
      onChange(pruned);
    }
    // Prune only when tool or storage filters change, not on every selection tick.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeStorageType, allFiles, codeInterpreterEnabled, fileSearchEnabled]);

  const showPicker = fileSearchEnabled || codeInterpreterEnabled;

  if (!showPicker) {
    return (
      <div className="rounded-lg border border-dashed p-4 text-sm text-muted-foreground">
        Enable <strong>File Search</strong> or <strong>Code Interpreter</strong> to attach Knowledge
        Base files to this agent.
      </div>
    );
  }

  return (
    <div className="space-y-3 rounded-lg border p-4">
      <div className="flex items-start gap-3">
        <FileText className="mt-0.5 h-5 w-5 shrink-0 text-muted-foreground" />
        <div className="space-y-1">
          <Label>Knowledge Base Files</Label>
          <p className="text-sm text-muted-foreground">
            Attach files from your Knowledge Base on active storage (
            {STORAGE_PROVIDER_LABELS[activeStorageType]}). Only files stored on the active provider
            are listed.
          </p>
        </div>
      </div>

      <div className="flex items-start gap-2 rounded-md border border-amber-200 bg-amber-50 px-3 py-2 text-sm text-amber-900">
        <AlertCircle className="mt-0.5 h-4 w-4 shrink-0" />
        <div className="space-y-1">
          <p>
            <strong>File Search</strong> on this platform supports{" "}
            <strong>.pdf</strong>, <strong>.docx</strong>, and <strong>.txt</strong> only.
          </p>
          {!codeInterpreterEnabled ? (
            <p className="text-xs">
              Spreadsheet files (.csv, .xlsx) are hidden until Code Interpreter is enabled.
            </p>
          ) : (
            <p className="text-xs">
              With Code Interpreter enabled, you can also attach{" "}
              {CODE_INTERPRETER_EXTENSIONS.map((ext) => `.${ext}`).join(", ")} files.
            </p>
          )}
        </div>
      </div>

      <div className="flex flex-wrap gap-2">
        {fileSearchEnabled &&
          PLATFORM_FILE_SEARCH_EXTENSIONS.map((extension) => (
            <Badge key={extension} variant="secondary">
              .{extension}
            </Badge>
          ))}
        {codeInterpreterEnabled &&
          CODE_INTERPRETER_EXTENSIONS.map((extension) => (
            <Badge key={extension} variant="outline">
              .{extension}
            </Badge>
          ))}
      </div>

      <KnowledgeFilePicker
        selectedFileIds={selectedFileIds}
        onChange={onChange}
        disabled={disabled || activeStorageQuery.isLoading}
        files={visibleFiles}
        isLoading={filesQuery.isLoading || activeStorageQuery.isLoading}
        emptyMessage={
          allowedExtensions.length === 0
            ? "Enable File Search or Code Interpreter to see attachable files."
            : `No matching files on ${STORAGE_PROVIDER_LABELS[activeStorageType]}. Upload ${allowedExtensions.map((ext) => `.${ext}`).join(", ")} files in Knowledge Base first.`
        }
      />
    </div>
  );
}
