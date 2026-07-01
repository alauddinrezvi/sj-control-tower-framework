import { useMemo, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { Badge } from "@/components/ui/badge";
import { ScrollArea } from "@/components/ui/scroll-area";
import { FileText, Loader2, Search } from "lucide-react";
import { listSelectableKnowledgeFiles, type KnowledgeFile } from "../api/file";

interface KnowledgeFilePickerProps {
  selectedFileIds: string[];
  onChange: (fileIds: string[]) => void;
  disabled?: boolean;
  files?: KnowledgeFile[];
  isLoading?: boolean;
  emptyMessage?: string;
}

export function KnowledgeFilePicker({
  selectedFileIds,
  onChange,
  disabled = false,
  files: filesProp,
  isLoading: isLoadingProp,
  emptyMessage = "No knowledge files found. Upload files in Knowledge Base first.",
}: KnowledgeFilePickerProps): JSX.Element {
  const [searchTerm, setSearchTerm] = useState("");

  const filesQuery = useQuery({
    queryKey: ["knowledge", "file-picker", "files"],
    queryFn: listSelectableKnowledgeFiles,
    enabled: filesProp === undefined,
  });

  const files = useMemo(() => filesProp ?? filesQuery.data ?? [], [filesProp, filesQuery.data]);
  const isLoading = isLoadingProp ?? (filesProp === undefined ? filesQuery.isLoading : false);

  const filteredFiles = useMemo(
    () => files.filter((file) => file.name.toLowerCase().includes(searchTerm.trim().toLowerCase())),
    [files, searchTerm],
  );

  const toggleFile = (fileId: string, checked: boolean): void => {
    if (checked) {
      onChange([...new Set([...selectedFileIds, fileId])]);
      return;
    }

    onChange(selectedFileIds.filter((id) => id !== fileId));
  };

  const renderFileRow = (file: KnowledgeFile): JSX.Element => {
    const isSelected = selectedFileIds.includes(file.id);

    return (
      <label
        key={file.id}
        className="flex cursor-pointer items-center gap-3 rounded-md border px-3 py-2 hover:bg-muted/50"
      >
        <Checkbox
          checked={isSelected}
          disabled={disabled}
          onCheckedChange={(checked) => toggleFile(file.id, checked === true)}
        />
        <FileText className="h-4 w-4 shrink-0 text-muted-foreground" />
        <div className="min-w-0 flex-1">
          <p className="truncate text-sm font-medium">{file.name}</p>
          <p className="text-xs text-muted-foreground">{file.size}</p>
        </div>
        {file.embeddingStatus && file.embeddingStatus !== "none" && (
          <Badge variant="outline" className="shrink-0 text-xs">
            {file.embeddingStatus}
          </Badge>
        )}
      </label>
    );
  };

  return (
    <div className="space-y-3">
      <div className="relative">
        <Search className="absolute left-3 top-3 h-4 w-4 text-muted-foreground" />
        <Input
          value={searchTerm}
          onChange={(event) => setSearchTerm(event.target.value)}
          placeholder="Search knowledge files..."
          className="pl-9"
          disabled={disabled}
        />
      </div>

      <div className="flex items-center justify-between text-sm text-muted-foreground">
        <span>{selectedFileIds.length} file(s) selected</span>
        {selectedFileIds.length > 0 && (
          <Button
            type="button"
            variant="ghost"
            size="sm"
            disabled={disabled}
            onClick={() => onChange([])}
          >
            Clear selection
          </Button>
        )}
      </div>

      {isLoading ? (
        <div className="flex h-32 items-center justify-center">
          <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
        </div>
      ) : filteredFiles.length === 0 ? (
        <p className="rounded-md border p-4 text-sm text-muted-foreground">{emptyMessage}</p>
      ) : (
        <ScrollArea className="h-56 rounded-md border p-2">
          <div className="space-y-2">{filteredFiles.map(renderFileRow)}</div>
        </ScrollArea>
      )}
    </div>
  );
}
