<template>
  <busy-spinner v-if="statsContent == null" />
  <div v-else>
    <debug-info-table v-for="item in statsContent.table" :key="item.key" :table-id="item.key" :module-id="item.value" />
    <debug-info-graph v-for="item in statsContent.graph" :key="item.key" :graph-id="item.key" :module-id="item.value" />
  </div>
</template>

<script lang="ts">
  import { useI18n } from 'vue-i18n'
  import { defineComponent, ref } from 'vue'
  import statusService from '../../../services/fairyNode/StatusService'
  import { StatsContent } from '../../../services/fairyNode/StatusService'

  import DebugInfoTable from './debug-info/DebugInfoTable.vue'
  import DebugInfoGraph from './debug-info/DebugInfoGraph.vue'

  export declare type OptionalStatsContent = StatsContent | undefined

  export default defineComponent({
    components: {
      DebugInfoTable,
      DebugInfoGraph,
    },
    setup() {
      const statsContent = ref(null)
      const { t } = useI18n()
      return {
        t,
        statsContent,
      }
    },
    data() {
      return {
        timerId: 0,
      }
    },
    mounted() {
      if (this.timerId == 0) {
        this.timerId = window.setInterval(() => {
          this.getData()
        }, 60 * 1000)
      }
      this.getData()
    },
    unmounted() {
      if (this.timerId != 0) {
        window.clearInterval(this.timerId)
        this.timerId = 0
      }
    },
    methods: {
      async getData() {
        this.statsContent = await statusService.getStatusContent()
        this.statsContent.table.sort(function (a, b) {
          return a.key.toLowerCase().localeCompare(b.key.toLowerCase())
        })
        this.statsContent.graph.sort(function (a, b) {
          return a.key.toLowerCase().localeCompare(b.key.toLowerCase())
        })
      },
    },
  })
</script>

<style lang="scss"></style>
