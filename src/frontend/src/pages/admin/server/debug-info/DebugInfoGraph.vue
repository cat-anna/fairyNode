<template>
  <va-card class="mb-2">
    <va-collapse v-model="visible" class="min-w-96" :header="moduleId" icon="material-icons-insert_chart">
      <!-- <va-card-title v-if="statsTable != null">
      title
    </va-card-title> -->
      <va-card-content>
        <busy-spinner v-if="graphSvg == ''" />
        <div v-else v-html="graphSvg"></div>
      </va-card-content>
    </va-collapse>
  </va-card>
</template>

<script lang="ts">
  import { useI18n } from 'vue-i18n'
  import { defineComponent, ref, Ref } from 'vue'
  import statusService from '../../../../services/fairyNode/StatusService'
  import { StatsTable } from '../../../../services/fairyNode/StatusService'

  export declare type OptionalStatsTable = StatsTable | undefined

  export default defineComponent({
    props: {
      graphId: { type: String, required: true },
      moduleId: { type: String, required: true },
    },
    setup() {
      const statsTable: Ref<OptionalStatsTable> = ref()
      const { t } = useI18n()
      return {
        t,
        statsTable,
      }
    },
    data() {
      return {
        timerId: 0,
        graphUrl: '',
        graphSvg: '',
        visible: false,
      }
    },
    watch: {
      async visible() {
        if (this.visible) {
          this.getData()
          this.subscribe()
        } else {
          this.clearSubscription()
        }
      },
    },

    // mounted() { },
    // unmounted() { },
    methods: {
      subscribe() {
        if (this.timerId == 0) {
          this.timerId = window.setInterval(() => {
            this.getData()
          }, 10 * 1000)
        }
      },
      clearSubscription() {
        if (this.timerId != 0) {
          window.clearInterval(this.timerId)
          this.timerId = 0
        }
      },
      // updateTitle() {},
      async getData() {
        if (this.visible) {
          const response = await statusService.getStatusGraphUrl(this.graphId)
          if (response.url != this.graphUrl) {
            this.graphUrl = response.url
            this.graphSvg = await fetch(response.url).then((response) => response.text())
          }
        }
      },
    },
  })
</script>

<style lang="scss"></style>
