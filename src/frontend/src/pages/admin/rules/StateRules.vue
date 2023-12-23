<template>
  <div>
    <va-card class="mb-2">
      <va-card-title> TODO selector </va-card-title>
      <va-card-content> </va-card-content>
    </va-card>

    <va-card class="mb-2">
      <va-card-title> TODO selected rule </va-card-title>
      <va-card-title>
        <div>left</div>
        <va-spacer />
        <div>
          <va-button plain @click="openCodeEditor">
            <va-icon name="material-icons-edit" />
            {{ t('rule.state.edit') }}
          </va-button>
        </div>
      </va-card-title>
      <va-card-content>
        <busy-spinner v-if="graphSvg == ''" />
        <div v-else v-html="graphSvg"></div>
      </va-card-content>
    </va-card>
  </div>
</template>

<script lang="ts">
  import { useI18n } from 'vue-i18n'
  import { defineComponent } from 'vue'
  import ruleStateService from '../../../services/fairyNode/RuleStateService'

  export default defineComponent({
    setup() {
      const { t } = useI18n()
      return { t }
    },
    data() {
      return {
        ruleName: 'first',
        graphUrl: '',
        timerId: 0,
        graphSvg: '',
      }
    },
    mounted() {
      this.getData()
      if (this.timerId == 0) {
        this.timerId = window.setInterval(() => {
          this.getData()
        }, 5 * 1000)
      }
    },
    unmounted() {
      if (this.timerId != 0) {
        window.clearInterval(this.timerId)
        this.timerId = 0
      }
    },

    methods: {
      // getStatusColor(v: string) {
      //   return deviceService.getStatusColor(v)
      // },
      // formatSeconds(v: number) {
      //   return formatting.formatSeconds(v)
      // },

      openCodeEditor() {
        // TODO
      },
      async getData() {
        const response = await ruleStateService.getGraphUrl(this.ruleName)
        if (response.url != this.graphUrl) {
          this.graphUrl = response.url
          this.graphSvg = await fetch(response.url).then((response) => response.text())
        }
      },
    },
  })
</script>

<style lang="scss"></style>
