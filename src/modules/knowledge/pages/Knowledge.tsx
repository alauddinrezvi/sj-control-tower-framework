import { useEffect, useMemo, useRef, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Skeleton } from "@/components/ui/skeleton";
import { Progress } from "@/components/ui/progress";
import { Switch } from "@/components/ui/switch";
import { Checkbox } from "@/components/ui/checkbox";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import {
  Avatar,
  AvatarFallback,
  AvatarImage,
} from "@/components/ui/avatar";
import {
  Download,
  Edit,
  Eye,
  FileText,
  Folder,
  Grid2X2,
  Home,
  Keyboard,
  List,
  MoreVertical,
  MoveRight,
  Plus,
  Search,
  Share2,
  Star,
  Trash2,
  Upload,
  EyeOff,
  Globe,
  Users,
} from "lucide-react";
import {
  Tooltip,
  TooltipContent,
  TooltipTrigger,
} from "@/components/ui/tooltip";
import { ActiveStorageIndicator } from "../components/ActiveStorageIndicator";
import { ManageAccessModal } from "../components/ManageAccessModal";
import { FilesSkeleton } from "../components/FilesSkeleton";
import { FilePreviewModal } from "../components/FilePreviewModal";
import { KnowledgeStatsBar } from "../components/KnowledgeStatsBar";
import { MAX_FILE_SIZE_BYTES, MAX_UPLOAD_FILES } from "../constants";
import {
  canManageItem,
  isOwner,
  isSharedWithMe,
} from "../utils/permissions";
import {
  isFileOnActiveStorage,
  STORAGE_PROVIDER_LABELS,
  useActiveStorageType,
} from "../hooks/useActiveStorageType";
import { useAuth } from "@/contexts/AuthContext";
import { useToast } from "@/hooks/use-toast";
import { cn, formatDate } from "@/lib/utils";
import {
  buildDuplicateResolutions,
  findDuplicateFiles,
  type DuplicateFile,
  type DuplicateResolutionStrategy,
} from "../utils/duplicateHandler";
import {
  bulkDeleteFiles,
  bulkUpdateFileVisibility,
  createFolder,
  deleteFile,
  deleteFolder,
  downloadFile,
  hideSharedResource,
  listFiles,
  listFolders,
  updateFile,
  updateFolder,
  uploadFiles,
  validateUploadFiles,
  type KnowledgeFile,
  type KnowledgeFolder,
  type SharedUser,
  type UploadFileOptions,
} from "../api/file";

type ViewMode = "grid" | "list";
type DialogName =
  | "createFolder"
  | "editFolder"
  | "upload"
  | "duplicates"
  | "renameFile"
  | "moveFile"
  | "shortcuts"
  | "preview"
  | null;

interface UploadProgressState {
  completed: number;
  total: number;
  fileName: string;
}

interface ManageAccessTarget {
  type: "file" | "folder";
  id: string;
  name: string;
  ownerId: string;
  sharedWith: SharedUser[];
}

const KNOWLEDGE_QUERY_KEYS = {
  folders: ["knowledge", "file-manager", "folders"] as const,
  files: (folderId: string | null) => ["knowledge", "file-manager", "files", folderId] as const,
};

function matchesSearch(value: string, searchTerm: string): boolean {
  return value.toLowerCase().includes(searchTerm.trim().toLowerCase());
}

function selectedFolderLabel(folderId: string | null, folders: KnowledgeFolder[]): string {
  if (!folderId) {
    return "Home";
  }

  return folders.find((folder) => folder.id === folderId)?.name ?? "Folder";
}

export default function Knowledge(): JSX.Element {
  const { user } = useAuth();
  const { toast } = useToast();
  const queryClient = useQueryClient();
  const searchInputRef = useRef<HTMLInputElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const [currentFolder, setCurrentFolder] = useState<string | null>(null);
  const [searchTerm, setSearchTerm] = useState("");
  const [folderViewMode, setFolderViewMode] = useState<ViewMode>("grid");
  const [fileViewMode, setFileViewMode] = useState<ViewMode>("grid");
  const [activeDialog, setActiveDialog] = useState<DialogName>(null);
  const [folderName, setFolderName] = useState("");
  const [folderColor, setFolderColor] = useState("#6b7280");
  const [selectedFiles, setSelectedFiles] = useState<File[]>([]);
  const [duplicates, setDuplicates] = useState<DuplicateFile[]>([]);
  const [selectedFile, setSelectedFile] = useState<KnowledgeFile | null>(null);
  const [selectedFolder, setSelectedFolder] = useState<KnowledgeFolder | null>(null);
  const [renameValue, setRenameValue] = useState("");
  const [moveFolderId, setMoveFolderId] = useState<string>("root");
  const [manageAccessTarget, setManageAccessTarget] = useState<ManageAccessTarget | null>(null);
  const [uploadIsPublic, setUploadIsPublic] = useState(false);
  const [uploadIsShared, setUploadIsShared] = useState(false);
  const [uploadIndexForSearch, setUploadIndexForSearch] = useState(false);
  const [uploadProgress, setUploadProgress] = useState<UploadProgressState | null>(null);
  const [selectedFileIds, setSelectedFileIds] = useState<Set<string>>(new Set());
  const [previewFile, setPreviewFile] = useState<KnowledgeFile | null>(null);

  const foldersQuery = useQuery({
    queryKey: KNOWLEDGE_QUERY_KEYS.folders,
    queryFn: listFolders,
  });

  const filesQuery = useQuery({
    queryKey: KNOWLEDGE_QUERY_KEYS.files(currentFolder),
    queryFn: () => listFiles({ folderId: currentFolder }),
  });

  const activeStorageQuery = useActiveStorageType();
  const activeStorageType = activeStorageQuery.data?.storageType ?? "local";

  const folders = useMemo(() => foldersQuery.data ?? [], [foldersQuery.data]);
  const files = useMemo(() => filesQuery.data?.data ?? [], [filesQuery.data?.data]);
  const loadingFolders = foldersQuery.isLoading;
  const loadingFiles = filesQuery.isLoading;
  const currentFolderName = selectedFolderLabel(currentFolder, folders);

  const visibleFolders = useMemo(
    () => (currentFolder ? [] : folders.filter((folder) => matchesSearch(folder.name, searchTerm))),
    [currentFolder, folders, searchTerm],
  );

  const visibleFiles = useMemo(
    () => files.filter((file) => matchesSearch(file.name, searchTerm)),
    [files, searchTerm],
  );

  const refreshKnowledge = async (): Promise<void> => {
    await Promise.all([
      queryClient.invalidateQueries({ queryKey: KNOWLEDGE_QUERY_KEYS.folders }),
      queryClient.invalidateQueries({ queryKey: KNOWLEDGE_QUERY_KEYS.files(currentFolder) }),
    ]);
  };

  const createFolderMutation = useMutation({
    mutationFn: () => createFolder(folderName, folderColor),
    onSuccess: async () => {
      setActiveDialog(null);
      setFolderName("");
      await refreshKnowledge();
      toast({ title: "Folder created", description: "Your folder is ready." });
    },
    onError: (error: Error) => {
      toast({ title: "Folder creation failed", description: error.message, variant: "destructive" });
    },
  });

  const updateFolderMutation = useMutation({
    mutationFn: ({ folderId, sharedWith }: { folderId: string; sharedWith?: SharedUser[] }) =>
      updateFolder(folderId, {
        name: folderName || undefined,
        color: folderColor,
        sharedWith,
      }),
    onSuccess: async () => {
      setActiveDialog(null);
      setSelectedFolder(null);
      await refreshKnowledge();
      toast({ title: "Folder updated", description: "Folder changes were saved." });
    },
    onError: (error: Error) => {
      toast({ title: "Folder update failed", description: error.message, variant: "destructive" });
    },
  });

  const deleteFolderMutation = useMutation({
    mutationFn: deleteFolder,
    onSuccess: async () => {
      if (selectedFolder?.id === currentFolder) {
        setCurrentFolder(null);
      }
      await refreshKnowledge();
      toast({ title: "Folder deleted", description: "The folder was removed." });
    },
    onError: (error: Error) => {
      toast({ title: "Folder delete failed", description: error.message, variant: "destructive" });
    },
  });

  const uploadMutation = useMutation({
    mutationFn: (filesToUpload: File[]) => {
      const options: UploadFileOptions = {
        isPublic: uploadIsPublic,
        isShared: uploadIsShared,
        indexForSearch: uploadIndexForSearch,
        onProgress: (completed, total, fileName) => {
          setUploadProgress({ completed, total, fileName });
        },
      };
      return uploadFiles(filesToUpload, currentFolder, options);
    },
    onSuccess: async (uploaded) => {
      setActiveDialog(null);
      setSelectedFiles([]);
      setDuplicates([]);
      setUploadProgress(null);
      setUploadIsPublic(false);
      setUploadIsShared(false);
      setUploadIndexForSearch(false);
      if (fileInputRef.current) {
        fileInputRef.current.value = "";
      }
      await refreshKnowledge();
      toast({ title: "Upload complete", description: `${uploaded.length} file(s) uploaded.` });
    },
    onError: (error: Error) => {
      setUploadProgress(null);
      toast({ title: "Upload failed", description: error.message, variant: "destructive" });
    },
  });

  const bulkDeleteMutation = useMutation({
    mutationFn: (fileIds: string[]) => bulkDeleteFiles(fileIds),
    onSuccess: async () => {
      setSelectedFileIds(new Set());
      await refreshKnowledge();
      toast({ title: "Files deleted", description: "Selected files were removed." });
    },
    onError: (error: Error) => {
      toast({ title: "Bulk delete failed", description: error.message, variant: "destructive" });
    },
  });

  const bulkVisibilityMutation = useMutation({
    mutationFn: ({
      fileIds,
      updates,
    }: {
      fileIds: string[];
      updates: { isPublic?: boolean; isShared?: boolean };
    }) => bulkUpdateFileVisibility(fileIds, updates),
    onSuccess: async () => {
      await refreshKnowledge();
      toast({ title: "Visibility updated", description: "Selected files were updated." });
    },
    onError: (error: Error) => {
      toast({ title: "Bulk update failed", description: error.message, variant: "destructive" });
    },
  });

  const updateFileMutation = useMutation({
    mutationFn: ({ fileId, input }: { fileId: string; input: Parameters<typeof updateFile>[1] }) =>
      updateFile(fileId, input),
    onSuccess: async () => {
      setActiveDialog(null);
      setSelectedFile(null);
      await refreshKnowledge();
      toast({ title: "File updated", description: "File changes were saved." });
    },
    onError: (error: Error) => {
      toast({ title: "File update failed", description: error.message, variant: "destructive" });
    },
  });

  const hideSharedItemMutation = useMutation({
    mutationFn: ({ resourceType, resourceId }: { resourceType: "file" | "folder"; resourceId: string }) =>
      hideSharedResource(resourceType, resourceId),
    onSuccess: async (_data, variables) => {
      if (variables.resourceType === "folder" && currentFolder === variables.resourceId) {
        setCurrentFolder(null);
      }
      await refreshKnowledge();
      toast({ title: "Removed from Knowledge Base", description: "This shared item was hidden from your list." });
    },
    onError: (error: Error) => {
      toast({ title: "Could not remove item", description: error.message, variant: "destructive" });
    },
  });

  const saveAccessMutation = useMutation({
    mutationFn: async ({ target, sharedWith }: { target: ManageAccessTarget; sharedWith: SharedUser[] }) => {
      if (target.type === "file") {
        return updateFile(target.id, { sharedWith });
      }
      return updateFolder(target.id, { sharedWith });
    },
    onSuccess: async () => {
      setManageAccessTarget(null);
      await refreshKnowledge();
      toast({ title: "Access updated", description: "Sharing settings were saved." });
    },
    onError: (error: Error) => {
      toast({ title: "Failed to update access", description: error.message, variant: "destructive" });
    },
  });

  const deleteFileMutation = useMutation({
    mutationFn: deleteFile,
    onSuccess: async () => {
      await refreshKnowledge();
      toast({ title: "File deleted", description: "The file was removed." });
    },
    onError: (error: Error) => {
      toast({ title: "File delete failed", description: error.message, variant: "destructive" });
    },
  });

  useEffect(() => {
    const handleShortcut = (event: KeyboardEvent): void => {
      if (event.ctrlKey && event.key.toLowerCase() === "n") {
        event.preventDefault();
        setActiveDialog("createFolder");
      }

      if (event.ctrlKey && event.key.toLowerCase() === "u") {
        event.preventDefault();
        setActiveDialog("upload");
      }

      if (event.ctrlKey && event.key.toLowerCase() === "f") {
        event.preventDefault();
        searchInputRef.current?.focus();
      }

      if (event.shiftKey && event.key === "?") {
        event.preventDefault();
        setActiveDialog("shortcuts");
      }

      if (event.key === "Escape") {
        setActiveDialog(null);
      }
    };

    window.addEventListener("keydown", handleShortcut);
    return () => window.removeEventListener("keydown", handleShortcut);
  }, []);

  const startEditFolder = (folder: KnowledgeFolder): void => {
    setSelectedFolder(folder);
    setFolderName(folder.name);
    setFolderColor(folder.color);
    setActiveDialog("editFolder");
  };

  const openManageAccess = (target: ManageAccessTarget): void => {
    setManageAccessTarget(target);
  };

  const startShareFolder = (folder: KnowledgeFolder): void => {
    openManageAccess({
      type: "folder",
      id: folder.id,
      name: folder.name,
      ownerId: folder.userId ?? user?.id ?? "",
      sharedWith: folder.sharedWith,
    });
  };

  const startRenameFile = (file: KnowledgeFile): void => {
    setSelectedFile(file);
    setRenameValue(file.name);
    setActiveDialog("renameFile");
  };

  const startMoveFile = (file: KnowledgeFile): void => {
    setSelectedFile(file);
    setMoveFolderId(file.folderId ?? "root");
    setActiveDialog("moveFile");
  };

  const startShareFile = (file: KnowledgeFile): void => {
    openManageAccess({
      type: "file",
      id: file.id,
      name: file.name,
      ownerId: file.userId ?? user?.id ?? "",
      sharedWith: file.sharedWith,
    });
  };

  const handleFileSelection = (fileList: FileList | null): void => {
    const nextFiles = Array.from(fileList ?? []);
    const validation = validateUploadFiles(nextFiles);
    if (!validation.valid) {
      toast({ title: "Invalid selection", description: validation.error, variant: "destructive" });
      if (fileInputRef.current) {
        fileInputRef.current.value = "";
      }
      return;
    }
    setSelectedFiles(nextFiles);
  };

  const submitUpload = (): void => {
    const validation = validateUploadFiles(selectedFiles);
    if (!validation.valid) {
      toast({ title: "Invalid upload", description: validation.error, variant: "destructive" });
      return;
    }

    const duplicateFiles = findDuplicateFiles(selectedFiles, files);

    if (duplicateFiles.length > 0) {
      setDuplicates(duplicateFiles);
      setActiveDialog("duplicates");
      return;
    }

    setUploadProgress({ completed: 0, total: selectedFiles.length, fileName: "" });
    uploadMutation.mutate(selectedFiles);
  };

  const toggleFileSelection = (fileId: string, checked: boolean): void => {
    setSelectedFileIds((current) => {
      const next = new Set(current);
      if (checked) {
        next.add(fileId);
      } else {
        next.delete(fileId);
      }
      return next;
    });
  };

  const renderOwnerBadge = (item: KnowledgeFolder | KnowledgeFile): JSX.Element | null => {
    if (!isSharedWithMe(item, user?.id)) {
      return null;
    }

    const initials = (item.ownerName ?? item.ownerEmail ?? "?")
      .split(" ")
      .map((part) => part[0])
      .join("")
      .slice(0, 2)
      .toUpperCase();

    return (
      <div className="flex items-center gap-2 text-xs text-muted-foreground">
        <Avatar className="h-6 w-6">
          {item.ownerAvatar && <AvatarImage src={item.ownerAvatar} alt={item.ownerName ?? "Owner"} />}
          <AvatarFallback>{initials}</AvatarFallback>
        </Avatar>
        <span className="truncate">
          {item.ownerName ?? "Shared owner"}
          {item.ownerEmail ? ` · ${item.ownerEmail}` : ""}
        </span>
      </div>
    );
  };

  const renderEmbeddingBadge = (file: KnowledgeFile): JSX.Element | null => {
    if (!file.embeddingStatus || file.embeddingStatus === "none") {
      return null;
    }

    const variant =
      file.embeddingStatus === "completed"
        ? "secondary"
        : file.embeddingStatus === "failed"
          ? "destructive"
          : "outline";

    return <Badge variant={variant}>{file.embeddingStatus}</Badge>;
  };

  const resolveDuplicates = async (strategy: DuplicateResolutionStrategy): Promise<void> => {
    const resolutions = buildDuplicateResolutions(selectedFiles, duplicates, strategy);
    const overwriteIds = resolutions
      .map((resolution) => resolution.existingFileId)
      .filter((id): id is string => Boolean(id));

    for (const fileId of overwriteIds) {
      await deleteFile(fileId);
    }

    uploadMutation.mutate(resolutions.map((resolution) => resolution.file));
  };

  const renderFolderCard = (folder: KnowledgeFolder): JSX.Element => {
    const owner = isOwner(folder, user?.id);
    const canManage = canManageItem(folder, user?.id);

    return (
      <Card key={folder.id} className="transition-shadow hover:shadow-md">
        <CardHeader className="pb-3">
          <div className="flex items-start justify-between gap-3">
            <button
              type="button"
              className="flex flex-1 items-center gap-3 text-left"
              onClick={() => setCurrentFolder(folder.id)}
            >
              <span className="flex h-10 w-10 items-center justify-center rounded-lg" style={{ background: folder.color }}>
                <Folder className="h-5 w-5 text-white" />
              </span>
              <span>
                <CardTitle className="line-clamp-1 text-base">{folder.name}</CardTitle>
                <CardDescription>
                  {folder.fileCount} file{folder.fileCount === 1 ? "" : "s"}
                </CardDescription>
              </span>
            </button>
            <FolderMenu folder={folder} owner={owner} canManage={canManage} />
          </div>
        </CardHeader>
        <CardContent className="space-y-2 text-xs text-muted-foreground">
          {renderOwnerBadge(folder)}
          <div className="flex items-center justify-between">
            <span>{formatDate(folder.modified)}</span>
            {folder.sharedWith.length > 0 && <Badge variant="outline">Shared</Badge>}
          </div>
        </CardContent>
      </Card>
    );
  };

  const renderFileCard = (file: KnowledgeFile): JSX.Element => {
    const owner = isOwner(file, user?.id);
    const canManage = canManageItem(file, user?.id);
    const storageActive = isFileOnActiveStorage(file.storageType, activeStorageType);
    const fileStorageLabel = STORAGE_PROVIDER_LABELS[file.storageType ?? "local"];
    const isSelected = selectedFileIds.has(file.id);

    const card = (
      <Card
        className={cn(
          "transition-all",
          storageActive
            ? "hover:shadow-md"
            : "cursor-not-allowed border-dashed opacity-55 grayscale hover:opacity-45",
          isSelected && "ring-2 ring-primary",
        )}
      >
        <CardHeader className="pb-3">
          <div className="flex items-start justify-between gap-3">
            <div className="flex items-center gap-3">
              {canManage && storageActive && (
                <Checkbox
                  checked={isSelected}
                  onCheckedChange={(checked) => toggleFileSelection(file.id, checked === true)}
                  aria-label={`Select ${file.name}`}
                />
              )}
              <span
                className={cn(
                  "flex h-10 w-10 items-center justify-center rounded-lg",
                  storageActive ? "bg-primary/10" : "bg-muted",
                )}
              >
                <FileText className={cn("h-5 w-5", storageActive ? "text-primary" : "text-muted-foreground")} />
              </span>
              <div>
                <CardTitle className={cn("line-clamp-1 text-base", !storageActive && "text-muted-foreground")}>
                  {file.name}
                </CardTitle>
                <CardDescription>{file.size}</CardDescription>
              </div>
            </div>
            {storageActive && canManage ? (
              <FileMenu file={file} owner={owner} canManage={canManage} storageActive={storageActive} />
            ) : storageActive || !owner ? (
              <FileMenu file={file} owner={owner} canManage={canManage} storageActive={storageActive} />
            ) : (
              <Button variant="ghost" size="icon" disabled className="pointer-events-none opacity-30" tabIndex={-1}>
                <MoreVertical className="h-4 w-4" />
              </Button>
            )}
          </div>
        </CardHeader>
        <CardContent className="space-y-3 text-xs text-muted-foreground">
          {renderOwnerBadge(file)}
          <div className="flex flex-wrap items-center gap-2">
            <Badge variant="secondary">{file.type}</Badge>
            <Badge variant={storageActive ? "secondary" : "outline"}>{file.storageType ?? "local"}</Badge>
            {renderEmbeddingBadge(file)}
            {!storageActive && (
              <Badge variant="outline" className="border-amber-300 bg-amber-50 text-amber-800">
                Inactive
              </Badge>
            )}
            {file.sharedWith.length > 0 && <Badge variant="outline">Shared</Badge>}
            {!owner && <Badge variant="outline">Shared with me</Badge>}
          </div>
          {!storageActive && (
            <p className="text-xs text-amber-700">
              Stored on {fileStorageLabel}. Switch active storage to manage this file.
            </p>
          )}
          <div className="flex items-center justify-between">
            <span>{formatDate(file.modified)}</span>
            {file.isStarred && <Star className="h-4 w-4 fill-yellow-400 text-yellow-400" />}
          </div>
        </CardContent>
      </Card>
    );

    if (storageActive) {
      return <div key={file.id}>{card}</div>;
    }

    return (
      <Tooltip key={file.id}>
        <TooltipTrigger asChild>
          <div className="h-full">{card}</div>
        </TooltipTrigger>
        <TooltipContent side="top" className="max-w-xs">
          This file is on {fileStorageLabel}. Enable {fileStorageLabel} in Admin → Storage to rename, move, or delete it.
        </TooltipContent>
      </Tooltip>
    );
  };

  const FolderMenu = ({
    folder,
    owner,
    canManage,
  }: {
    folder: KnowledgeFolder;
    owner: boolean;
    canManage: boolean;
  }): JSX.Element => (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button variant="ghost" size="icon">
          <MoreVertical className="h-4 w-4" />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end">
        {canManage ? (
          <>
            <DropdownMenuItem onClick={() => startEditFolder(folder)}>
              <Edit className="mr-2 h-4 w-4" />
              Edit
            </DropdownMenuItem>
            {owner && (
              <DropdownMenuItem onClick={() => startShareFolder(folder)}>
                <Share2 className="mr-2 h-4 w-4" />
                Manage access
              </DropdownMenuItem>
            )}
            {owner && (
              <>
                <DropdownMenuSeparator />
                <DropdownMenuItem
                  className="text-destructive"
                  onClick={() => {
                    if (window.confirm(`Delete "${folder.name}"? Files inside will move to root.`)) {
                      setSelectedFolder(folder);
                      deleteFolderMutation.mutate(folder.id);
                    }
                  }}
                >
                  <Trash2 className="mr-2 h-4 w-4" />
                  Delete
                </DropdownMenuItem>
              </>
            )}
          </>
        ) : (
          <DropdownMenuItem
            onClick={() => hideSharedItemMutation.mutate({ resourceType: "folder", resourceId: folder.id })}
          >
            <EyeOff className="mr-2 h-4 w-4" />
            Remove from my Knowledge Base
          </DropdownMenuItem>
        )}
      </DropdownMenuContent>
    </DropdownMenu>
  );

  const FileMenu = ({
    file,
    owner,
    canManage,
    storageActive,
  }: {
    file: KnowledgeFile;
    owner: boolean;
    canManage: boolean;
    storageActive: boolean;
  }): JSX.Element => (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button variant="ghost" size="icon">
          <MoreVertical className="h-4 w-4" />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end">
        <DropdownMenuItem
          disabled={!storageActive}
          onClick={() => {
            setPreviewFile(file);
            setActiveDialog("preview");
          }}
        >
          <Eye className="mr-2 h-4 w-4" />
          Preview
        </DropdownMenuItem>
        <DropdownMenuItem
          disabled={!storageActive}
          onClick={() => {
            void downloadFile(file).catch((error: unknown) => {
              toast({
                title: "Download failed",
                description: error instanceof Error ? error.message : "Unable to download file",
                variant: "destructive",
              });
            });
          }}
        >
          <Download className="mr-2 h-4 w-4" />
          Download
        </DropdownMenuItem>
        {canManage ? (
          <>
            <DropdownMenuItem
              disabled={!storageActive}
              onClick={() => updateFileMutation.mutate({ fileId: file.id, input: { isStarred: !file.isStarred } })}
            >
              <Star className="mr-2 h-4 w-4" />
              {file.isStarred ? "Unstar" : "Star"}
            </DropdownMenuItem>
            <DropdownMenuItem disabled={!storageActive} onClick={() => startRenameFile(file)}>
              <Edit className="mr-2 h-4 w-4" />
              Rename
            </DropdownMenuItem>
            <DropdownMenuItem disabled={!storageActive} onClick={() => startMoveFile(file)}>
              <MoveRight className="mr-2 h-4 w-4" />
              Move
            </DropdownMenuItem>
            {owner && (
              <DropdownMenuItem disabled={!storageActive} onClick={() => startShareFile(file)}>
                <Share2 className="mr-2 h-4 w-4" />
                Manage access
              </DropdownMenuItem>
            )}
            {owner && (
              <>
                <DropdownMenuSeparator />
                <DropdownMenuItem
                  disabled={!storageActive}
                  className="text-destructive"
                  onClick={() => {
                    if (window.confirm(`Delete "${file.name}"?`)) {
                      deleteFileMutation.mutate(file.id);
                    }
                  }}
                >
                  <Trash2 className="mr-2 h-4 w-4" />
                  Delete
                </DropdownMenuItem>
              </>
            )}
          </>
        ) : (
          <>
            <DropdownMenuSeparator />
            <DropdownMenuItem
              onClick={() => hideSharedItemMutation.mutate({ resourceType: "file", resourceId: file.id })}
            >
              <EyeOff className="mr-2 h-4 w-4" />
              Remove from my Knowledge Base
            </DropdownMenuItem>
          </>
        )}
      </DropdownMenuContent>
    </DropdownMenu>
  );

  const renderFileListRow = (file: KnowledgeFile): JSX.Element => {
    const owner = isOwner(file, user?.id);
    const canManage = canManageItem(file, user?.id);
    const storageActive = isFileOnActiveStorage(file.storageType, activeStorageType);
    const isSelected = selectedFileIds.has(file.id);

    return (
      <TableRow key={file.id} className={cn(!storageActive && "opacity-60")}>
        <TableCell>
          {canManage && storageActive && (
            <Checkbox
              checked={isSelected}
              onCheckedChange={(checked) => toggleFileSelection(file.id, checked === true)}
              aria-label={`Select ${file.name}`}
            />
          )}
        </TableCell>
        <TableCell>
          <div className="flex items-center gap-2">
            <FileText className="h-4 w-4 text-muted-foreground" />
            <span className="font-medium">{file.name}</span>
            {file.isStarred && <Star className="h-3 w-3 fill-yellow-400 text-yellow-400" />}
          </div>
          {renderOwnerBadge(file)}
        </TableCell>
        <TableCell>{file.size}</TableCell>
        <TableCell>{formatDate(file.modified)}</TableCell>
        <TableCell>
          <div className="flex flex-wrap gap-1">
            <Badge variant="outline">{file.storageType ?? "local"}</Badge>
            {renderEmbeddingBadge(file)}
            {!owner && <Badge variant="outline">Shared</Badge>}
          </div>
        </TableCell>
        <TableCell className="text-right">
          {storageActive && (
            <FileMenu file={file} owner={owner} canManage={canManage} storageActive={storageActive} />
          )}
        </TableCell>
      </TableRow>
    );
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
        <div>
          <h1 className="text-3xl font-bold tracking-tight">Knowledge Base</h1>
          <p className="text-muted-foreground">Manage folders, files, sharing, and knowledge assets for agents and RAG.</p>
        </div>
        <div className="flex flex-wrap gap-2">
          <Button variant="outline" onClick={() => setActiveDialog("shortcuts")}>
            <Keyboard className="mr-2 h-4 w-4" />
            Shortcuts
          </Button>
          <Button variant="outline" onClick={() => setActiveDialog("createFolder")}>
            <Plus className="mr-2 h-4 w-4" />
            New Folder
          </Button>
          <Button onClick={() => setActiveDialog("upload")}>
            <Upload className="mr-2 h-4 w-4" />
            Upload Files
          </Button>
        </div>
      </div>

      <ActiveStorageIndicator />

      <KnowledgeStatsBar />

      <Card>
        <CardContent className="flex flex-col gap-4 p-4 lg:flex-row lg:items-center lg:justify-between">
          <div className="flex items-center gap-2 text-sm">
            <Button variant="ghost" size="sm" onClick={() => setCurrentFolder(null)}>
              <Home className="mr-2 h-4 w-4" />
              Home
            </Button>
            {currentFolder && (
              <>
                <span className="text-muted-foreground">/</span>
                <Badge variant="secondary">{currentFolderName}</Badge>
              </>
            )}
          </div>
          <div className="relative w-full lg:max-w-sm">
            <Search className="absolute left-3 top-3 h-4 w-4 text-muted-foreground" />
            <Input
              ref={searchInputRef}
              value={searchTerm}
              onChange={(event) => setSearchTerm(event.target.value)}
              placeholder="Search visible folders and files..."
              className="pl-9"
            />
          </div>
        </CardContent>
      </Card>

      {!currentFolder && (
        <section className="space-y-4">
          <div className="flex items-center justify-between">
            <h2 className="text-xl font-semibold">Folders</h2>
            <div className="flex gap-1">
              <Button variant={folderViewMode === "grid" ? "secondary" : "ghost"} size="icon" onClick={() => setFolderViewMode("grid")}>
                <Grid2X2 className="h-4 w-4" />
              </Button>
              <Button variant={folderViewMode === "list" ? "secondary" : "ghost"} size="icon" onClick={() => setFolderViewMode("list")}>
                <List className="h-4 w-4" />
              </Button>
            </div>
          </div>
          {loadingFolders ? (
            <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
              {Array.from({ length: 3 }).map((_, index) => (
                <Skeleton key={index} className="h-28" />
              ))}
            </div>
          ) : visibleFolders.length === 0 ? (
            <Card className="p-6 text-center text-muted-foreground">No folders found.</Card>
          ) : (
            <div className={folderViewMode === "grid" ? "grid gap-4 sm:grid-cols-2 lg:grid-cols-3" : "space-y-3"}>
              {visibleFolders.map(renderFolderCard)}
            </div>
          )}
        </section>
      )}

      <section className="space-y-4">
        <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <h2 className="text-xl font-semibold">{currentFolder ? `${currentFolderName} Files` : "Root Files"}</h2>
          <div className="flex flex-wrap items-center gap-2">
            {selectedFileIds.size > 0 && (
              <>
                <Badge variant="secondary">{selectedFileIds.size} selected</Badge>
                <Button
                  variant="outline"
                  size="sm"
                  disabled={bulkVisibilityMutation.isPending}
                  onClick={() =>
                    bulkVisibilityMutation.mutate({
                      fileIds: [...selectedFileIds],
                      updates: { isPublic: true },
                    })
                  }
                >
                  <Globe className="mr-2 h-4 w-4" />
                  Make public
                </Button>
                <Button
                  variant="outline"
                  size="sm"
                  disabled={bulkVisibilityMutation.isPending}
                  onClick={() =>
                    bulkVisibilityMutation.mutate({
                      fileIds: [...selectedFileIds],
                      updates: { isShared: true },
                    })
                  }
                >
                  <Users className="mr-2 h-4 w-4" />
                  Mark shared
                </Button>
                <Button
                  variant="destructive"
                  size="sm"
                  disabled={bulkDeleteMutation.isPending}
                  onClick={() => {
                    if (window.confirm(`Delete ${selectedFileIds.size} selected file(s)?`)) {
                      bulkDeleteMutation.mutate([...selectedFileIds]);
                    }
                  }}
                >
                  <Trash2 className="mr-2 h-4 w-4" />
                  Delete
                </Button>
              </>
            )}
            <Button variant={fileViewMode === "grid" ? "secondary" : "ghost"} size="icon" onClick={() => setFileViewMode("grid")}>
              <Grid2X2 className="h-4 w-4" />
            </Button>
            <Button variant={fileViewMode === "list" ? "secondary" : "ghost"} size="icon" onClick={() => setFileViewMode("list")}>
              <List className="h-4 w-4" />
            </Button>
          </div>
        </div>
        {loadingFiles ? (
          <FilesSkeleton count={6} mode={fileViewMode} />
        ) : visibleFiles.length === 0 ? (
          <Card className="p-10 text-center">
            <FileText className="mx-auto mb-3 h-10 w-10 text-muted-foreground" />
            <h3 className="font-semibold">No files found</h3>
            <p className="text-sm text-muted-foreground">Upload files to this location to connect them with knowledge workflows.</p>
          </Card>
        ) : fileViewMode === "list" ? (
          <div className="rounded-md border">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead className="w-10" />
                  <TableHead>Name</TableHead>
                  <TableHead>Size</TableHead>
                  <TableHead>Modified</TableHead>
                  <TableHead>Storage</TableHead>
                  <TableHead className="text-right">Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>{visibleFiles.map(renderFileListRow)}</TableBody>
            </Table>
          </div>
        ) : (
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {visibleFiles.map(renderFileCard)}
          </div>
        )}
      </section>

      <Dialog open={activeDialog === "createFolder" || activeDialog === "editFolder"} onOpenChange={(open) => setActiveDialog(open ? activeDialog : null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{activeDialog === "editFolder" ? "Edit Folder" : "Create Folder"}</DialogTitle>
            <DialogDescription>Folders organize files at the Knowledge Base root.</DialogDescription>
          </DialogHeader>
          <div className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="folder-name">Name</Label>
              <Input id="folder-name" value={folderName} onChange={(event) => setFolderName(event.target.value)} />
            </div>
            <div className="space-y-2">
              <Label htmlFor="folder-color">Color</Label>
              <Input id="folder-color" type="color" value={folderColor} onChange={(event) => setFolderColor(event.target.value)} />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setActiveDialog(null)}>Cancel</Button>
            <Button
              disabled={!folderName.trim() || createFolderMutation.isPending || updateFolderMutation.isPending}
              onClick={() => {
                if (activeDialog === "editFolder" && selectedFolder) {
                  updateFolderMutation.mutate({ folderId: selectedFolder.id });
                } else {
                  createFolderMutation.mutate();
                }
              }}
            >
              Save
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={activeDialog === "upload"} onOpenChange={(open) => setActiveDialog(open ? "upload" : null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Upload Files</DialogTitle>
            <DialogDescription>
              Upload up to {MAX_UPLOAD_FILES} files (max 50 MB each) into {currentFolderName}. Files will be stored in{" "}
              {STORAGE_PROVIDER_LABELS[activeStorageQuery.data?.storageType ?? "local"]}.
            </DialogDescription>
          </DialogHeader>
          <ActiveStorageIndicator compact />
          <Input
            ref={fileInputRef}
            type="file"
            multiple
            onChange={(event) => handleFileSelection(event.target.files)}
          />
          <div className="grid gap-3 sm:grid-cols-2">
            <div className="flex items-center justify-between rounded-md border px-3 py-2">
              <div>
                <Label htmlFor="upload-public">Public</Label>
                <p className="text-xs text-muted-foreground">Anyone can access</p>
              </div>
              <Switch id="upload-public" checked={uploadIsPublic} onCheckedChange={setUploadIsPublic} />
            </div>
            <div className="flex items-center justify-between rounded-md border px-3 py-2">
              <div>
                <Label htmlFor="upload-shared">Shared</Label>
                <p className="text-xs text-muted-foreground">Mark as shared asset</p>
              </div>
              <Switch id="upload-shared" checked={uploadIsShared} onCheckedChange={setUploadIsShared} />
            </div>
          </div>
          <div className="flex items-center justify-between rounded-md border px-3 py-2">
            <div>
              <Label htmlFor="upload-index">Index for search</Label>
              <p className="text-xs text-muted-foreground">Queue embeddings after upload</p>
            </div>
            <Switch id="upload-index" checked={uploadIndexForSearch} onCheckedChange={setUploadIndexForSearch} />
          </div>
          {selectedFiles.length > 0 && (
            <div className="max-h-48 space-y-2 overflow-y-auto rounded-md border p-2">
              {selectedFiles.map((file) => (
                <div key={`${file.name}-${file.lastModified}`} className="flex items-center justify-between text-sm">
                  <span className="truncate">{file.name}</span>
                  <span className={cn("text-muted-foreground", file.size > MAX_FILE_SIZE_BYTES && "text-destructive")}>
                    {Math.round(file.size / 1024)} KB
                  </span>
                </div>
              ))}
            </div>
          )}
          {uploadProgress && (
            <div className="space-y-2">
              <div className="flex justify-between text-sm text-muted-foreground">
                <span>
                  Uploading {uploadProgress.fileName || "files"} ({uploadProgress.completed}/{uploadProgress.total})
                </span>
                <span>{Math.round((uploadProgress.completed / uploadProgress.total) * 100)}%</span>
              </div>
              <Progress value={(uploadProgress.completed / uploadProgress.total) * 100} />
            </div>
          )}
          <DialogFooter>
            <Button variant="outline" onClick={() => setActiveDialog(null)}>Cancel</Button>
            <Button disabled={uploadMutation.isPending || selectedFiles.length === 0} onClick={submitUpload}>
              Upload
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <FilePreviewModal
        file={previewFile}
        open={activeDialog === "preview"}
        onOpenChange={(open) => {
          if (!open) {
            setActiveDialog(null);
            setPreviewFile(null);
          }
        }}
      />

      <Dialog open={activeDialog === "duplicates"} onOpenChange={(open) => setActiveDialog(open ? "duplicates" : null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Duplicate files found</DialogTitle>
            <DialogDescription>Choose how to resolve files with names that already exist in this folder.</DialogDescription>
          </DialogHeader>
          <div className="space-y-2">
            {duplicates.map((duplicate) => (
              <div key={duplicate.selectedFile.name} className="rounded-md border p-3 text-sm">
                {duplicate.selectedFile.name}
              </div>
            ))}
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => resolveDuplicates("skip")}>Skip</Button>
            <Button variant="outline" onClick={() => resolveDuplicates("version")}>Keep Versions</Button>
            <Button onClick={() => resolveDuplicates("overwrite")}>Overwrite</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={activeDialog === "renameFile"} onOpenChange={(open) => setActiveDialog(open ? "renameFile" : null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Rename File</DialogTitle>
            <DialogDescription>Change the display name while keeping the stable file ID.</DialogDescription>
          </DialogHeader>
          <Input value={renameValue} onChange={(event) => setRenameValue(event.target.value)} />
          <DialogFooter>
            <Button variant="outline" onClick={() => setActiveDialog(null)}>Cancel</Button>
            <Button
              disabled={!renameValue.trim() || updateFileMutation.isPending}
              onClick={() => selectedFile && updateFileMutation.mutate({ fileId: selectedFile.id, input: { name: renameValue } })}
            >
              Rename
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={activeDialog === "moveFile"} onOpenChange={(open) => setActiveDialog(open ? "moveFile" : null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Move File</DialogTitle>
            <DialogDescription>Select a target folder or move the file back to root.</DialogDescription>
          </DialogHeader>
          <Select value={moveFolderId} onValueChange={setMoveFolderId}>
            <SelectTrigger>
              <SelectValue placeholder="Target folder" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="root">Root</SelectItem>
              {folders.map((folder) => (
                <SelectItem key={folder.id} value={folder.id}>{folder.name}</SelectItem>
              ))}
            </SelectContent>
          </Select>
          <DialogFooter>
            <Button variant="outline" onClick={() => setActiveDialog(null)}>Cancel</Button>
            <Button
              disabled={updateFileMutation.isPending}
              onClick={() => selectedFile && updateFileMutation.mutate({
                fileId: selectedFile.id,
                input: { folderId: moveFolderId === "root" ? null : moveFolderId },
              })}
            >
              Move
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <ManageAccessModal
        open={manageAccessTarget !== null}
        onOpenChange={(open) => !open && setManageAccessTarget(null)}
        resourceName={manageAccessTarget?.name ?? ""}
        ownerId={manageAccessTarget?.ownerId ?? user?.id ?? ""}
        sharedWith={manageAccessTarget?.sharedWith ?? []}
        isSaving={saveAccessMutation.isPending}
        onSave={async (sharedWith) => {
          if (!manageAccessTarget) {
            return;
          }
          await saveAccessMutation.mutateAsync({ target: manageAccessTarget, sharedWith });
        }}
      />

      <Dialog open={activeDialog === "shortcuts"} onOpenChange={(open) => setActiveDialog(open ? "shortcuts" : null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Keyboard Shortcuts</DialogTitle>
          </DialogHeader>
          <div className="space-y-3 text-sm">
            <Shortcut keys="Ctrl+N" label="Create folder" />
            <Shortcut keys="Ctrl+U" label="Upload files" />
            <Shortcut keys="Ctrl+F" label="Focus search" />
            <Shortcut keys="Shift+?" label="Show shortcuts" />
            <Shortcut keys="Escape" label="Close dialogs" />
          </div>
        </DialogContent>
      </Dialog>
    </div>
  );
}

function Shortcut({ keys, label }: { keys: string; label: string }): JSX.Element {
  return (
    <div className="flex items-center justify-between rounded-md border p-3">
      <span>{label}</span>
      <kbd className="rounded bg-muted px-2 py-1 text-xs">{keys}</kbd>
    </div>
  );
}
