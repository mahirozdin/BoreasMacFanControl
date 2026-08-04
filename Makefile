# Zephyr — komut yüzeyi
# Kaynak: blueprint §16.1
# Tüm kapılar scripts/gates/ altındadır ve doğrudan çalıştırılabilir.

SHELL := /bin/bash
.DEFAULT_GOAL := help

GATES := scripts/gates

# ---------------------------------------------------------------- yardım

.PHONY: help
help: ## Bu listeyi göster
	@echo "Zephyr — kullanılabilir hedefler:"
	@echo ""
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'
	@echo ""

# ---------------------------------------------------------------- kapılar

.PHONY: next
next: ## Sıradaki yapılabilir atomik işi göster (manuel blokajları atlar)
	@scripts/next-task.py

.PHONY: check
check: gate-names blueprint-check docs-check gate-layers gate-deps gate-privacy gate-i18n gate-daemon gate-coverage ## Tüm kapıları çalıştır
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

.PHONY: gate-coverage
gate-coverage: ## Core satır kapsamı >= %85 (bloklayıcı)
	@$(GATES)/check-coverage.sh

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

PACKAGES := Core SharedIPC HardwareKit

.PHONY: build
build: ## Tüm SPM paketlerini derle
	@for p in $(PACKAGES); do \
		printf '  %-12s ' "$$p"; \
		( cd Packages/$$p && swift build 2>&1 | tail -1 ) || exit 1; \
	done

.PHONY: test
test: ## Tüm testleri çalıştır
	@for p in $(PACKAGES); do \
		if [ -d "Packages/$$p/Tests" ]; then \
			printf '  %-12s ' "$$p"; \
			( cd Packages/$$p && swift test 2>&1 | grep -E 'Test run with|error:' | tail -1 ) || exit 1; \
		fi; \
	done

# NOT: buradaki '|| echo ✓' bir SAHTE KAPI idi — swift format gerçek ihlaller
# bulup çıkarken mesaj "taranacak kaynak yok" diyor ve kapı yeşil görünüyordu.
# Var olan dizinler açıkça toplanıyor ve çıkış kodu artık yutulmuyor.
FORMAT_DIRS := $(shell for d in Packages App Daemon CLI Widget; do [ -d "$$d" ] && echo "$$d"; done)

.PHONY: lint
lint: ## SwiftLint + swift format denetimi (yazmaz)
	@command -v swiftlint >/dev/null 2>&1 || { echo "✗ swiftlint yok — brew bundle"; exit 1; }
	@swiftlint lint --quiet --strict && echo "  ✓ swiftlint"
	@if [ -n "$(FORMAT_DIRS)" ]; then \
		swift format lint --recursive --strict $(FORMAT_DIRS) && echo "  ✓ swift format"; \
	else \
		echo "  ○ swift format: taranacak dizin yok"; \
	fi

.PHONY: format
format: ## swift format ile biçimlendir (dosyaları DEĞİŞTİRİR)
	@if [ -n "$(FORMAT_DIRS)" ]; then \
		swift format --in-place --recursive $(FORMAT_DIRS) && echo "  ✓ biçimlendirildi"; \
	fi

.PHONY: release
release: ## İmzala, notarize et, DMG üret
	@echo "P8'de etkinleşecek (bkz. TODO.md)"

.PHONY: clean
clean: ## Derleme çıktılarını temizle
	@rm -rf .build build dist DerivedData .gate-tmp
	@echo "✓ Temizlendi."
