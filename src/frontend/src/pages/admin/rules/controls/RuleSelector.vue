<template>
  <va-dropdown trigger="hover" class="mr-2 mb-2 min-w-96" preset="primary" @open="refetchRuleList">
    <template #anchor>
      <va-button>
        <va-icon :name="'material-icons-arrow_drop_down'" />
        <span v-if="selectedStateRule == ''">{{ t('rules.state.select_rule') }}</span>
        <span v-else-if="selectedStateRule == '@'">{{ t('rules.state.selected_all') }} </span>
        <span v-else>{{ t('rules.state.selected') }} {{ selectedStateRule }}</span>
      </va-button>
    </template>

    <va-dropdown-content>
      <busy-spinner v-if="ruleList.length == 0" />
      <va-scroll-container class="max-h-[400px]" vertical>
        <va-list>
          <va-list-item class="flex py-1 w-full">
            <va-button plain class="w-full" @click="selectRule('@')">
              {{ t('rules.state.select_all') }}
            </va-button>
            <va-divider />
          </va-list-item>
          <va-divider />
          <va-list-item v-for="info in ruleList" :key="info.id" class="flex py-1 w-full">
            <va-button plain class="w-full" @click="selectRule(info.id)">
              {{ info.name }}
            </va-button>
          </va-list-item>
        </va-list>
      </va-scroll-container>
    </va-dropdown-content>
  </va-dropdown>
</template>

<script lang="ts">
  import { useI18n } from 'vue-i18n'
  import { defineComponent } from 'vue'
  import { storeToRefs } from 'pinia'

  import { useGlobalStore } from '../../../../stores/global-store'

  import { RuleStatus } from '../../../../services/fairyNode/RuleStateService'
  import ruleStateService from '../../../../services/fairyNode/RuleStateService'

  export default defineComponent({
    emits: ['RuleSelected'],
    setup(props, { emit }) {
      const { t } = useI18n()
      const globalStore = useGlobalStore()
      const { selectedStateRule } = storeToRefs(globalStore)
      return { t, emit, selectedStateRule }
    },
    data() {
      return {
        ruleList: new Array<RuleStatus>(),
      }
    },
    mounted() {
      this.refetchRuleList()
    },
    // unmounted() {},
    methods: {
      selectRule(name: string) {
        this.selectedStateRule = name
        if (name == '@') {
          var list: Array<string> = []
          this.ruleList.forEach((e) => list.push(e.id))
          this.emit('RuleSelected', list)
        } else {
          this.emit('RuleSelected', [name])
        }
      },
      async refetchRuleList() {
        ruleStateService.getRuleList().then((data) => {
          var sortFunc = function (a: any, b: any) {
            var a_name = a.name || ''
            var b_name = b.name || ''
            return a_name.toLowerCase().localeCompare(b_name.toLowerCase())
          }

          data.rules.sort(sortFunc)
          if (this.ruleList.length == 0 || this.selectedStateRule == '@') {
            this.ruleList = data.rules
            this.selectRule(this.selectedStateRule)
          } else {
            this.ruleList = data.rules
          }

          if (this.selectedStateRule == '' && this.ruleList.length > 0) {
            this.selectRule(this.ruleList[0].id)
          }
        })
      },
    },
  })
</script>

<style lang="scss"></style>
