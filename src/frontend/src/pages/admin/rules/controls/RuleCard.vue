<template>
  <va-card class="mb-2">
    <va-card-title> </va-card-title>
    <va-card-title>
      <div>{{ t('rules.state.selected') }} {{ ruleName }}</div>
      <va-spacer />
      <rule-options-drop-down :rule-id="ruleId" @edit="enterEditMode" @remove="removeRule" />
    </va-card-title>
    <va-card-content>
      <rule-graph v-if="mode == 'graph'" :rule-id="ruleId" />
      <rule-code-editor v-else-if="mode == 'code'" :rule-id="ruleId" @close-editor="onCloseEditor" />
      <div v-else>unknown</div>
    </va-card-content>
  </va-card>
</template>

<script lang="ts">
  import { useI18n } from 'vue-i18n'
  import { defineComponent } from 'vue'
  import { useModal, useToast } from 'vuestic-ui'

  import ruleStateService from '../../../../services/fairyNode/RuleStateService'

  import RuleGraph from './RuleGraph.vue'
  import RuleCodeEditor from './RuleCodeEditor.vue'
  import RuleOptionsDropDown from './RuleOptionsDropDown.vue'

  export default defineComponent({
    components: {
      RuleGraph,
      RuleOptionsDropDown,
      RuleCodeEditor,
    },
    props: {
      ruleId: {
        required: true,
        type: String,
      },
    },
    emits: ['RuleRemoved'],
    setup(props, { emit }) {
      const { t } = useI18n()
      const { init } = useToast()
      const { confirm } = useModal()
      return { t, emit, showModalConfirm: confirm, toastShow: init }
    },
    data() {
      return {
        ruleName: '?',
        mode: 'graph',
      }
    },
    mounted() {
      this.ruleName = this.ruleId
      this.getDetails()
    },
    // unmounted() {},
    methods: {
      async getDetails() {
        ruleStateService.getRuleDetails(this.ruleId).then((data) => {
          if (data.name) {
            this.ruleName = data.name
          }
        })
      },
      removeRule() {
        this.showModalConfirm({
          message: this.t('rules.state.modal.rule_removal_confirm'),
          blur: true,
          onOk: () => this.triggerRuleRemoval(),
        })
      },
      triggerRuleRemoval() {
        ruleStateService
          .deleteRule(this.ruleId)
          .then(() => {
            this.emit('RuleRemoved', this.ruleId)
            this.toastShow({
              message: this.t('rules.state.toast.rule_removed'),
              color: 'success',
            })
          })
          .catch(() => {
            this.toastShow({
              message: this.t('rules.state.toast.failed_to_remove_rule'),
              color: 'warning',
            })
          })
        // .finally(() => {})
      },
      enterEditMode() {
        this.mode = 'code'
      },
      onCloseEditor() {
        this.mode = 'graph'
      },
    },
  })
</script>

<style lang="scss"></style>
