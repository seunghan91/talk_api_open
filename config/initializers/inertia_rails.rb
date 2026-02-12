# Inertia.js Rails Configuration
InertiaRails.configure do |config|
  # Vite 빌드 해시를 Inertia 버전으로 사용 (캐시 무효화)
  config.version = ViteRuby.digest

  # SSR 비활성화 (CSR만 사용)
  config.ssr_enabled = false

  # API 컨트롤러에 영향주지 않도록 default_render 비활성화
  # Web 컨트롤러에서만 명시적으로 render inertia: 사용
  config.default_render = false

  # Inertia protocol forward-compatibility
  config.always_include_errors_hash = true
end
