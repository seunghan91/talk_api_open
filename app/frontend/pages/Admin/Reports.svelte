<script>
  import { router } from "@inertiajs/svelte";
  import Card from "$components/common/Card.svelte";
  import Button from "$components/common/Button.svelte";
  import Badge from "$components/common/Badge.svelte";
  import { timeAgo } from "$lib/utils.js";

  let { reports = [], pagination = {}, filter = null } = $props();

  const statusLabels = {
    pending: "대기중",
    processed: "처리됨",
    rejected: "기각됨",
  };

  const statusVariants = {
    pending: "warning",
    processed: "success",
    rejected: "default",
  };

  function processReport(reportId) {
    if (confirm("이 신고를 처리하시겠습니까?")) {
      router.put(`/admin/reports/${reportId}/process`);
    }
  }

  function rejectReport(reportId) {
    if (confirm("이 신고를 기각하시겠습니까?")) {
      router.put(`/admin/reports/${reportId}/reject`);
    }
  }
</script>

<div class="min-h-screen bg-slate-50">
  <header class="border-b border-slate-200 bg-white px-6 py-4">
    <div class="flex items-center gap-3">
      <a href="/admin" class="text-slate-500 hover:text-slate-700">← 대시보드</a>
      <h1 class="text-xl font-bold text-slate-900">🚨 신고 관리</h1>
    </div>
  </header>

  <main class="p-6">
    <!-- 필터 -->
    <div class="mb-4 flex gap-2">
      <Button href="/admin/reports" variant={!filter ? "primary" : "secondary"} size="sm">전체</Button>
      <Button href="/admin/reports?status=pending" variant={filter === "pending" ? "primary" : "secondary"} size="sm">대기중</Button>
      <Button href="/admin/reports?status=processed" variant={filter === "processed" ? "primary" : "secondary"} size="sm">처리됨</Button>
      <Button href="/admin/reports?status=rejected" variant={filter === "rejected" ? "primary" : "secondary"} size="sm">기각됨</Button>
    </div>

    <div class="space-y-3">
      {#each reports as report (report.id)}
        <Card>
          <div class="flex items-start justify-between">
            <div class="flex-1">
              <div class="flex items-center gap-2">
                <Badge variant={statusVariants[report.status] || "default"}>
                  {statusLabels[report.status] || report.status}
                </Badge>
                <span class="text-xs text-slate-400">{timeAgo(report.created_at)}</span>
              </div>
              <p class="mt-2 text-sm text-slate-900">{report.reason || "사유 없음"}</p>
              <p class="mt-1 text-xs text-slate-500">
                신고자: #{report.reporter_id} → 피신고자: #{report.reported_id}
              </p>
            </div>

            {#if report.status === "pending"}
              <div class="ml-4 flex gap-2">
                <Button onclick={() => processReport(report.id)} variant="primary" size="sm">처리</Button>
                <Button onclick={() => rejectReport(report.id)} variant="ghost" size="sm">기각</Button>
              </div>
            {/if}
          </div>
        </Card>
      {/each}
    </div>

    <!-- 페이지네이션 -->
    {#if pagination.total_pages > 1}
      <div class="mt-4 flex justify-center gap-2">
        {#if pagination.current_page > 1}
          <Button href="/admin/reports?page={pagination.current_page - 1}" variant="ghost" size="sm">← 이전</Button>
        {/if}
        <span class="flex items-center text-sm text-slate-500">{pagination.current_page} / {pagination.total_pages}</span>
        {#if pagination.current_page < pagination.total_pages}
          <Button href="/admin/reports?page={pagination.current_page + 1}" variant="ghost" size="sm">다음 →</Button>
        {/if}
      </div>
    {/if}
  </main>
</div>
