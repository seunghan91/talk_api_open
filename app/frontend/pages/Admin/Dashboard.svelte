<script>
  import Card from "$components/common/Card.svelte";
  import Button from "$components/common/Button.svelte";
  import { timeAgo } from "$lib/utils.js";

  let { stats = {}, recent_reports = [] } = $props();

  const statCards = [
    { key: "users_count", label: "전체 유저", icon: "👥", color: "text-sky-600 bg-sky-50" },
    { key: "users_today_count", label: "오늘 가입", icon: "📈", color: "text-teal-600 bg-teal-50" },
    { key: "broadcasts_count", label: "방송 수", icon: "📢", color: "text-violet-600 bg-violet-50" },
    { key: "pending_reports_count", label: "미처리 신고", icon: "🚨", color: "text-rose-600 bg-rose-50" },
  ];

  const statusColors = {
    pending: "bg-amber-100 text-amber-700",
    processed: "bg-teal-100 text-teal-700",
    rejected: "bg-slate-100 text-slate-600",
  };
</script>

<div class="min-h-screen bg-slate-50">
  <!-- 헤더 -->
  <header class="border-b border-slate-200 bg-white px-6 py-4">
    <div class="flex items-center justify-between">
      <div class="flex items-center gap-3">
        <span class="text-2xl">⚙️</span>
        <h1 class="text-xl font-bold text-slate-900">Talkk Admin</h1>
      </div>
      <span class="text-sm text-slate-500">관리자님 👤</span>
    </div>
  </header>

  <div class="flex">
    <!-- 사이드바 -->
    <aside class="hidden w-56 border-r border-slate-200 bg-white md:block">
      <nav class="space-y-1 p-4">
        <a href="/admin" class="flex items-center gap-2 rounded-lg bg-sky-50 px-3 py-2 text-sm font-medium text-sky-700">
          📊 대시보드
        </a>
        <a href="/admin/users" class="flex items-center gap-2 rounded-lg px-3 py-2 text-sm text-slate-600 hover:bg-slate-50">
          👥 사용자
        </a>
        <a href="/admin/reports" class="flex items-center gap-2 rounded-lg px-3 py-2 text-sm text-slate-600 hover:bg-slate-50">
          🚨 신고
        </a>
        <a href="/admin/analytics" class="flex items-center gap-2 rounded-lg px-3 py-2 text-sm text-slate-600 hover:bg-slate-50">
          📈 분석
        </a>
      </nav>
    </aside>

    <!-- 메인 콘텐츠 -->
    <main class="flex-1 p-6">
      <!-- 통계 카드 -->
      <div class="mb-8 grid grid-cols-2 gap-4 lg:grid-cols-4">
        {#each statCards as card}
          <Card>
            <div class="flex items-center gap-3">
              <div class="flex h-10 w-10 items-center justify-center rounded-lg {card.color}">
                <span class="text-xl">{card.icon}</span>
              </div>
              <div>
                <p class="text-2xl font-bold text-slate-900">{stats[card.key] || 0}</p>
                <p class="text-xs text-slate-500">{card.label}</p>
              </div>
            </div>
          </Card>
        {/each}
      </div>

      <!-- 최근 신고 -->
      <Card>
        <div class="mb-4 flex items-center justify-between">
          <h2 class="text-lg font-semibold text-slate-900">🚨 미처리 신고</h2>
          <Button href="/admin/reports" variant="ghost" size="sm">전체 보기 →</Button>
        </div>

        {#if recent_reports.length === 0}
          <p class="py-8 text-center text-sm text-slate-500">미처리 신고가 없습니다</p>
        {:else}
          <div class="space-y-3">
            {#each recent_reports as report (report.id)}
              <div class="flex items-center justify-between rounded-lg border border-slate-100 p-3">
                <div class="flex-1">
                  <p class="text-sm font-medium text-slate-900">{report.reason || "사유 없음"}</p>
                  <p class="text-xs text-slate-500">{timeAgo(report.created_at)}</p>
                </div>
                <span class="rounded-full px-2 py-0.5 text-xs font-medium {statusColors[report.status] || statusColors.pending}">
                  {report.status}
                </span>
              </div>
            {/each}
          </div>
        {/if}
      </Card>
    </main>
  </div>
</div>
