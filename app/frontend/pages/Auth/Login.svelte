<script>
  import { router } from "@inertiajs/svelte";
  import Button from "$components/common/Button.svelte";

  let phone_number = $state("");
  let loading = $state(false);
  let errors = $state({});

  function formatPhone(value) {
    const digits = value.replace(/\D/g, "");
    if (digits.length <= 3) return digits;
    if (digits.length <= 7) return `${digits.slice(0, 3)}-${digits.slice(3)}`;
    return `${digits.slice(0, 3)}-${digits.slice(3, 7)}-${digits.slice(7, 11)}`;
  }

  function handlePhoneInput(e) {
    const formatted = formatPhone(e.target.value);
    phone_number = formatted;
  }

  function handleSubmit(e) {
    e.preventDefault();
    const raw = phone_number.replace(/\D/g, "");

    if (raw.length < 10 || raw.length > 11) {
      errors = { phone_number: "올바른 전화번호를 입력해주세요." };
      return;
    }

    loading = true;
    errors = {};

    router.post("/auth/login", { phone_number: raw }, {
      onFinish: () => { loading = false; },
      onError: (err) => { errors = err; },
    });
  }
</script>

<div class="flex min-h-screen items-center justify-center bg-gradient-to-br from-sky-50 via-white to-cyan-50 px-4">
  <div class="w-full max-w-sm">
    <!-- 로고 -->
    <div class="mb-10 text-center">
      <div class="mb-4 text-6xl">☁️</div>
      <h1 class="bg-gradient-to-r from-sky-500 to-cyan-400 bg-clip-text text-4xl font-bold tracking-tight text-transparent">
        T A L K K
      </h1>
      <p class="mt-2 text-sm text-slate-500">음성으로 연결되는 세상</p>
    </div>

    <!-- 로그인 폼 -->
    <form onsubmit={handleSubmit} class="space-y-4">
      <div>
        <label for="phone" class="mb-1.5 block text-sm font-medium text-slate-700">전화번호</label>
        <div class="flex items-center gap-2 rounded-xl border border-slate-200 bg-white px-4 py-3 transition-colors focus-within:border-sky-400 focus-within:ring-2 focus-within:ring-sky-100">
          <span class="text-sm text-slate-500">🇰🇷 +82</span>
          <input
            id="phone"
            type="tel"
            placeholder="010-0000-0000"
            value={phone_number}
            oninput={handlePhoneInput}
            class="flex-1 bg-transparent text-slate-900 outline-none placeholder:text-slate-400"
            maxlength="13"
            autocomplete="tel"
          />
        </div>
        {#if errors.phone_number}
          <p class="mt-1.5 text-xs text-rose-500">{errors.phone_number}</p>
        {/if}
      </div>

      <Button type="submit" variant="primary" size="xl" {loading} class="w-full">
        {loading ? "발송 중..." : "인증번호 요청"}
      </Button>
    </form>

    <!-- 하단 링크 -->
    <div class="mt-8 flex justify-center gap-4 text-xs text-slate-400">
      <a href="/terms" class="hover:text-slate-600">이용약관</a>
      <span>|</span>
      <a href="/privacy" class="hover:text-slate-600">개인정보처리방침</a>
    </div>
  </div>
</div>
