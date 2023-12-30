<template>
  <div>
    <busy-spinner v-if="graphSvg == ''" />
    <div v-else v-html="graphSvg"></div>
  </div>
</template>

<script lang="ts">
  import { useI18n } from 'vue-i18n'
  import { defineComponent } from 'vue'
  import ruleStateService from '../../../../services/fairyNode/RuleStateService'

  export default defineComponent({
    props: {
      ruleId: {
        required: true,
        type: String,
      },
    },
    setup() {
      const { t } = useI18n()
      return { t }
    },
    data() {
      return {
        graphUrl: '',
        graphSvg: '',
        timerId: 0,
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
      openCodeEditor() {
        // TODO
      },
      async getData() {
        const response = await ruleStateService.getRuleGraphUrl(this.ruleId)
        if (response.url != this.graphUrl) {
          this.graphUrl = response.url
          this.graphSvg = await fetch(response.url).then((response) => response.text())
        }
      },
    },
  })
</script>

<style lang="scss"></style>
