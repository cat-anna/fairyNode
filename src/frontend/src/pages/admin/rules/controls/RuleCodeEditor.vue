<template>
  <div>
    <div class="pb-4">
      <va-button class="mx-1" @click="$emit('closeEditor')">
        <va-icon :name="'material-icons-clear'" />
        {{ t('rules.state.cancel') }}
      </va-button>
      <va-button class="mx-1" :disabled="!validation_success && !validation_pending && !validation_delay" @click="postCode(true)">
        <va-icon :name="'material-icons-done'" />
        {{ t('rules.state.update_code') }}
      </va-button>
    </div>
    <div class="flex font-mono">
      <busy-spinner v-if="busy" />
      <codemirror
        v-model="code"
        class="w-full code-text-area"
        placeholder="Code goes here..."
        :autofocus="true"
        :indent-with-tab="false"
        :tab-size="2"
        :extensions="extensions"
        :style="{ height: 'auto', 'min-height': '5rem', width: '100%' }"
        @ready="handleReady"
        @change="onChange"
      />
    </div>
    <div>
      <div v-for="item in codeErrors" :key="item.message" class="text-sm text-red-900">
        {{ t('rules.state.line') }} {{ item.line }}: {{ item.error }}
      </div>
    </div>
  </div>
</template>

<script lang="ts">
  import { useI18n } from 'vue-i18n'
  import { defineComponent, shallowRef, computed } from 'vue'
  import { useToast } from 'vuestic-ui'

  import { useGlobalStore } from '../../../../stores/global-store'

  import { CodeError } from '../../../../services/fairyNode/RuleStateService'
  import ruleStateService from '../../../../services/fairyNode/RuleStateService'

  import { Codemirror } from 'vue-codemirror'
  import { oneDark } from '@codemirror/theme-one-dark'
  import { StreamLanguage } from '@codemirror/language'
  import { lua } from '@codemirror/legacy-modes/mode/lua'

  import { linter, Diagnostic, setDiagnostics } from '@codemirror/lint'

  export default defineComponent({
    components: {
      Codemirror,
    },
    props: {
      ruleId: {
        required: true,
        type: String,
      },
    },
    emits: ['closeEditor'],

    setup(props, { emit }) {
      const { t } = useI18n()
      const { init } = useToast()

      const luaLang = StreamLanguage.define(lua)
      const globalStore = useGlobalStore()

      const editorView = shallowRef<EditorView>()
      const codeLinter = linter(() => [])

      const handleReady = ({ view }: any) => {
        editorView.value = view
      }

      const extensions = computed(() => {
        const result = [codeLinter, luaLang]
        if (globalStore.currentTheme == 'dark') {
          result.push(oneDark)
        }
        return result
      })

      return {
        t,
        emit,
        toastShow: init,
        extensions,
        handleReady,
        editorView,
      }
    },
    data() {
      return {
        code: '',
        busy: false,
        validation_success: true,
        validation_in_progress: false,
        validation_pending: false,
        validation_delay: false,
        validation_delay_timer: null,
        codeErrors: Array<CodeError>(),
      }
    },
    mounted() {
      this.loadCode()
    },
    // unmounted() {},
    methods: {
      loadCode() {
        this.busy = true
        ruleStateService
          .getRuleCode(this.ruleId)
          .then((code) => {
            this.code = code
            this.validation_success = true
          })
          .catch(() => {
            this.code = ''
            this.emit('closeEditor')
            this.toastShow({
              message: this.t('rules.state.toast.failed_to_load_code'),
              color: 'warning',
            })
          })
          .finally(() => {
            this.busy = false
          })
      },
      onChange() {
        this.validation_delay = true
        if (this.validation_delay_timer) {
          clearTimeout(this.validation_delay_timer)
        }
        this.validation_delay_timer = setTimeout(() => {
          this.validation_delay = false
          this.validation_delay_timer = null
          this.validate()
        }, 1000)
      },

      async translateErrors(errors: Array<CodeError>) {
        this.codeErrors = errors
        let diagnostics: Diagnostic[] = []
        let doc = this.editorView.state.doc

        errors.forEach((item) => {
          let line = doc.line(item.line)
          diagnostics.push({
            from: line.from,
            to: line.to,
            severity: 'error',
            message: item.error || item.message || 'unknown',
            actions: [],
          })
        })

        let tr = setDiagnostics(this.editorView.state, diagnostics)
        this.editorView.dispatch(tr)
      },
      async validate() {
        if (this.validation_in_progress) {
          this.validation_pending = true
          return
        }

        this.validation_in_progress = true
        this.validation_pending = false

        ruleStateService
          .validateCode(this.code)
          .then((result) => {
            this.validation_success = result.validation_success
            if (this.validation_success) {
              this.translateErrors([])
            } else {
              this.translateErrors(result.errors)
            }
          })
          .catch(() => {
            this.validation_success = false
          })
          .finally(() => {
            this.validation_in_progress = false
            if (this.validation_pending) {
              this.validate()
            }
          })
      },
      postCode(wantClose: boolean) {
        this.busy = true
        ruleStateService
          .setRuleCode(this.ruleId, this.code)
          .then(() => {
            if (wantClose) {
              this.emit('closeEditor')
              this.toastShow({
                message: this.t('rules.state.toast.code_upload_success'),
                color: 'success',
              })
            }
          })
          .catch(() => {
            this.toastShow({
              message: this.t('rules.state.toast.failed_to_load_code'),
              color: 'warning',
            })
          })
          .finally(() => {
            this.busy = false
          })
      },
    },
  })
</script>

<style lang="scss">
  .code-text-area {
    --va-font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, 'Liberation Mono', 'Courier New', monospace;
  }
</style>
