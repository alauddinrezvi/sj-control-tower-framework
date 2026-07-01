import { Skeleton } from "@/components/ui/skeleton";
import { cn } from "@/lib/utils";

interface FilesSkeletonProps {
  count?: number;
  mode?: "grid" | "list";
}

export function FilesSkeleton({ count = 6, mode = "grid" }: FilesSkeletonProps): JSX.Element {
  if (mode === "list") {
    return (
      <div className="rounded-md border">
        {Array.from({ length: count }).map((_, index) => (
          <div
            key={index}
            className="flex items-center gap-4 border-b px-4 py-3 last:border-b-0"
          >
            <Skeleton className="h-4 w-4 rounded" />
            <Skeleton className="h-8 w-8 rounded" />
            <Skeleton className="h-4 flex-1" />
            <Skeleton className="h-4 w-16" />
            <Skeleton className="h-4 w-24" />
            <Skeleton className="h-4 w-20" />
            <Skeleton className="h-8 w-8 rounded" />
          </div>
        ))}
      </div>
    );
  }

  return (
    <div className={cn("grid gap-4 sm:grid-cols-2 lg:grid-cols-3")}>
      {Array.from({ length: count }).map((_, index) => (
        <Skeleton key={index} className="h-36" />
      ))}
    </div>
  );
}
