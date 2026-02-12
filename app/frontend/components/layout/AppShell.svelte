<script>
  import { page } from "@inertiajs/svelte";
  import Sidebar from "./Sidebar.svelte";
  import BottomNav from "./BottomNav.svelte";
  import Header from "./Header.svelte";
  import Toast from "../common/Toast.svelte";
  import { sidebarOpen, isMobile } from "$lib/stores.js";

  let { children } = $props();

  let windowWidth = $state(typeof window !== "undefined" ? window.innerWidth : 1024);

  $effect(() => {
    if (typeof window === "undefined") return;
    const handleResize = () => {
      windowWidth = window.innerWidth;
      isMobile.set(windowWidth < 768);
    };
    handleResize();
    window.addEventListener("resize", handleResize);
    return () => window.removeEventListener("resize", handleResize);
  });

  let mobile = $derived(windowWidth < 768);
</script>

<div class="flex h-screen overflow-hidden bg-slate-50">
  <!-- 사이드바 (데스크톱) -->
  {#if !mobile}
    <Sidebar />
  {/if}

  <!-- 메인 컨텐츠 영역 -->
  <div class="flex flex-1 flex-col overflow-hidden">
    <Header />

    <main class="flex-1 overflow-y-auto">
      <div class="mx-auto max-w-4xl px-4 py-6 sm:px-6 lg:px-8">
        {@render children()}
      </div>
    </main>

    <!-- 하단 네비게이션 (모바일) -->
    {#if mobile}
      <BottomNav />
    {/if}
  </div>
</div>

<Toast />
