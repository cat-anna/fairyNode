<template>
  <va-card class="mb-2">
    <!-- <va-card-title> {{ t('rules.state.title') }} </va-card-title> -->
    <va-card-content>
      <busy-spinner v-if="busy" />
      <div v-else-if="opened" class="flex">
        <va-button class="px-2" plain color="danger" @click="opened = false">
          <va-icon :name="'material-icons-clear'" />
        </va-button>
        <va-button class="px-2" plain color="success" @click="createRule">
          <va-icon :name="'material-icons-done'" />
        </va-button>
        <div class="w-1/4 px-2">
          <va-input v-model="value" placeholder="unnamed rule" :label="t('rules.state.rule_name_label')" inner-label />
        </div>
      </div>
      <div v-else>
        <va-button class="px-2" plain @click="opened = true">
          <va-icon :name="'material-icons-add'" />
        </va-button>
      </div>
    </va-card-content>
  </va-card>
</template>

<script lang="ts">
  import { useI18n } from 'vue-i18n'
  import { defineComponent } from 'vue'
  import { useToast } from 'vuestic-ui'

  import ruleStateService from '../../../../services/fairyNode/RuleStateService'
  // import RuleGraph from './RuleGraph.vue'

  export default defineComponent({
    components: {},
    props: {},
    emits: ['ruleAdded'],
    setup(props, { emit }) {
      const { t } = useI18n()
      const { init } = useToast()
      return { t, emit, toastShow: init }
    },
    data() {
      return {
        opened: false,
        busy: false,
        value: 'unnamed rule',
      }
    },
    // mounted() { },
    // unmounted() {},
    methods: {
      createRule() {
        this.busy = true
        this.opened = false

        ruleStateService
          .createRule(this.value)
          .then((result) => {
            if (result.id == null) {
              throw Error()
            }
            this.emit('ruleAdded', result.id)
            this.toastShow({
              message: this.t('rules.state.toast.rule_added'),
              color: 'success',
            })
          })
          .catch(() => {
            this.toastShow({
              message: this.t('rules.state.toast.failed_to_add_rule'),
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

<style lang="scss"></style>
