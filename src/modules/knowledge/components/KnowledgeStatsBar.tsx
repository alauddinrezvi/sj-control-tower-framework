import { useQuery } from "@tanstack/react-query";
import { Card, CardContent } from "@/components/ui/card";
import { FileText, Share2, Star, HardDrive } from "lucide-react";
import { formatBytes } from "@/lib/utils";
import { getFileStatistics } from "../api/file";

export function KnowledgeStatsBar(): JSX.Element {
  const statsQuery = useQuery({
    queryKey: ["knowledge", "file-manager", "statistics"],
    queryFn: getFileStatistics,
  });

  const stats = statsQuery.data;

  if (statsQuery.isLoading) {
    return (
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        {Array.from({ length: 4 }).map((_, index) => (
          <Card key={index}>
            <CardContent className="h-20 p-4" />
          </Card>
        ))}
      </div>
    );
  }

  if (!stats) {
    return <></>;
  }

  const statItems = [
    { label: "Total files", value: String(stats.totalFiles), icon: FileText },
    { label: "Total size", value: formatBytes(stats.totalSizeBytes), icon: HardDrive },
    { label: "Starred", value: String(stats.starredCount), icon: Star },
    { label: "Shared", value: String(stats.sharedCount), icon: Share2 },
  ];

  return (
    <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
      {statItems.map((item) => (
        <Card key={item.label}>
          <CardContent className="flex items-center gap-3 p-4">
            <item.icon className="h-5 w-5 text-muted-foreground" />
            <div>
              <p className="text-xs text-muted-foreground">{item.label}</p>
              <p className="text-lg font-semibold">{item.value}</p>
            </div>
          </CardContent>
        </Card>
      ))}
    </div>
  );
}
