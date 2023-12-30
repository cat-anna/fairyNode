<template>
  <div>
    <va-card class="mb-2">
      <va-card-title> {{ t('rules.state.title') }} </va-card-title>
      <va-card-content>
        <rule-selector @rule-selected="onRuleSelected" />
      </va-card-content>
    </va-card>

    <rule-card v-for="rule in selectedRule" :key="rule" :rule-id="rule" @rule-removed="removeCard" />

    <add-rule @rule-added="onRuleAdded" />
  </div>
</template>

<script lang="ts">
  import { useI18n } from 'vue-i18n'
  import { defineComponent } from 'vue'
  // import ruleStateService from '../../../services/fairyNode/RuleStateService'

  import RuleSelector from './controls/RuleSelector.vue'
  import RuleCard from './controls/RuleCard.vue'
  import AddRule from './controls/AddRule.vue'

  export default defineComponent({
    components: {
      RuleSelector,
      RuleCard,
      AddRule,
    },
    setup() {
      const { t } = useI18n()
      return { t }
    },
    data() {
      return {
        selectedRule: new Array<string>(),
      }
    },
    // mounted() { },
    // unmounted() { },
    methods: {
      onRuleAdded(id: string) {
        this.selectedRule.push(id)
      },
      onRuleSelected(list: Array<string>) {
        this.selectedRule = list
      },
      removeCard(id: string) {
        this.selectedRule = this.selectedRule.filter((item) => item != id)
      },
    },
  })
</script>

<style lang="scss"></style>
