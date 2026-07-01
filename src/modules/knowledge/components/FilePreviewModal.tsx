import { useEffect, useState } from "react";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Loader2 } from "lucide-react";
import type { KnowledgeFile } from "../api/file";
import { getFilePreviewUrl } from "../api/file";

interface FilePreviewModalProps {
  file: KnowledgeFile | null;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

function isPreviewableImage(mimeType: string): boolean {
  return mimeType.startsWith("image/");
}

function isPreviewablePdf(mimeType: string): boolean {
  return mimeType.includes("pdf");
}

function isPreviewableText(mimeType: string, fileName: string): boolean {
  const extension = fileName.split(".").pop()?.toLowerCase() ?? "";
  return (
    mimeType.startsWith("text/") ||
    mimeType.includes("json") ||
    mimeType.includes("markdown") ||
    ["md", "txt", "csv", "json", "xml", "html", "css", "js", "ts", "tsx", "jsx"].includes(extension)
  );
}

export function FilePreviewModal({ file, open, onOpenChange }: FilePreviewModalProps): JSX.Element {
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [textContent, setTextContent] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!open || !file) {
      setPreviewUrl(null);
      setTextContent(null);
      setError(null);
      return;
    }

    let cancelled = false;

    const loadPreview = async (): Promise<void> => {
      setIsLoading(true);
      setError(null);
      setTextContent(null);

      try {
        const url = await getFilePreviewUrl(file);
        if (cancelled) {
          return;
        }

        setPreviewUrl(url);

        if (isPreviewableText(file.mimeType, file.name)) {
          const response = await fetch(url);
          const text = await response.text();
          if (!cancelled) {
            setTextContent(text.slice(0, 50000));
          }
        }
      } catch (previewError) {
        if (!cancelled) {
          setError(previewError instanceof Error ? previewError.message : "Failed to load preview");
        }
      } finally {
        if (!cancelled) {
          setIsLoading(false);
        }
      }
    };

    void loadPreview();

    return () => {
      cancelled = true;
    };
  }, [file, open]);

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-h-[85vh] max-w-4xl overflow-hidden">
        <DialogHeader>
          <DialogTitle>{file?.name ?? "File preview"}</DialogTitle>
          <DialogDescription>
            {file ? `${file.size} · ${file.mimeType || file.type}` : "Preview file contents"}
          </DialogDescription>
        </DialogHeader>

        <div className="max-h-[65vh] overflow-auto rounded-md border bg-muted/30 p-2">
          {isLoading && (
            <div className="flex h-48 items-center justify-center">
              <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
            </div>
          )}

          {!isLoading && error && (
            <p className="p-4 text-sm text-destructive">{error}</p>
          )}

          {!isLoading && !error && file && previewUrl && isPreviewableImage(file.mimeType) && (
            <img src={previewUrl} alt={file.name} className="mx-auto max-h-[60vh] object-contain" />
          )}

          {!isLoading && !error && file && previewUrl && isPreviewablePdf(file.mimeType) && (
            <iframe src={previewUrl} title={file.name} className="h-[60vh] w-full rounded" />
          )}

          {!isLoading && !error && textContent !== null && (
            <pre className="whitespace-pre-wrap break-words p-4 text-sm">{textContent}</pre>
          )}

          {!isLoading && !error && file && previewUrl && !isPreviewableImage(file.mimeType) && !isPreviewablePdf(file.mimeType) && textContent === null && (
            <div className="space-y-3 p-4 text-sm text-muted-foreground">
              <p>Inline preview is not available for this file type.</p>
              <a href={previewUrl} target="_blank" rel="noopener noreferrer" className="text-primary underline">
                Open file in new tab
              </a>
            </div>
          )}
        </div>
      </DialogContent>
    </Dialog>
  );
}
