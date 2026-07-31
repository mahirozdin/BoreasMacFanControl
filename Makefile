# Boreas — komut yüzeyi
# Kaynak: blueprint §16.1
# Tüm kapılar scripts/gates/ altındadır ve doğrudan çalıştırılabilir.

SHELL := /bin/bash
.DEFAULT_GOAL := help

GATES := scripts/gates

# ---------------------------------------------------------------- yardım

.PHONY: help
help: ## Bu listeyi göster
	@echo "Boreas — kullanılabilir hedefler:"
	@echo ""
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'
	@echo ""

# ---------------------------------------------------------------- kapılar

.PHONY: check
check: gate-names blueprint-check docs-check gate-layers gate-deps gate-privacy gate-i18n gate-daemon ## Tüm kapıları çalıştır
	@echo ""
	@echo "✓ Tüm kapılar tamamlandı."

.PHONY: gate-names
gate-names: ## H1/Y5/Y6 — üçüncü taraf ürün adı ve karşılaştırmalı pazarlama taraması
	@$(GATES)/check-names.sh

.PHONY: blueprint-check
blueprint-check: ## Dondurulmuş blueprint kopyası dokunulmamış mı
	@$(GATES)/check-blueprint.sh

.PHONY: docs-check
docs-check: ## Kırık link, izlenebilirlik matrisi hedefleri, ADR senkronu
	@$(GATES)/check-docs.sh

.PHONY: gate-layers
gate-layers: ## M1/M2 — Core katman saflığı ve Mock kapsamı
	@$(GATES)/check-layers.sh

.PHONY: gate-deps
gate-deps: ## T4/H5 — sıfır bağımlılık kuralı ve lisans uyumu
	@$(GATES)/check-deps.sh

.PHONY: gate-privacy
gate-privacy: ## P1/P2 — telemetri SDK'sı ve beklenmeyen ağ kullanımı
	@$(GATES)/check-privacy.sh

.PHONY: gate-i18n
gate-i18n: ## Y1/Y2 — sabit yazılmış kullanıcı metni
	@$(GATES)/check-i18n.sh

.PHONY: gate-daemon
gate-daemon: ## M4/M5/M6 — daemon XPC yüzeyi sınırları
	@$(GATES)/check-daemon.sh

# ---------------------------------------------------------------- geliştirme
# Not: aşağıdaki hedefler P1'de (depo iskeleti) etkinleşir.

.PHONY: bootstrap
bootstrap: ## Yerel geliştirme ortamını kur ve doğrula
	@scripts/bootstrap.sh

.PHONY: generate
generate: ## project.yml'den Xcode projesini üret
	@command -v xcodegen >/dev/null 2>&1 \
		|| { echo "✗ xcodegen yok. 'brew install xcodegen' çalıştır."; exit 1; }
	@xcodegen generate

.PHONY: build
build: ## Uygulamayı derle
	@echo "P1'de etkinleşecek (bkz. TODO.md)"

.PHONY: test
test: ## Testleri çalıştır
	@echo "P2'de etkinleşecek (bkz. TODO.md)"

.PHONY: lint
lint: ## swift-format + SwiftLint
	@echo "P1'de etkinleşecek (bkz. TODO.md)"

.PHONY: clean
clean: ## Derleme çıktılarını temizle
	@rm -rf .build build dist DerivedData .gate-tmp
	@echo "✓ Temizlendi."
