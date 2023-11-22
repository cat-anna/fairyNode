<template>
  <va-card class="mb-2">
    <va-card-title>{{ t('charts.options_title') }}</va-card-title>
    <va-card-content>
      <duration-selector @duration-changed="updateChartDuration" />
    </va-card-content>
  </va-card>

  <chart-card
    v-for="(chart, index) in charts"
    :key="chart.id"
    class="mb-2 chart_card"
    :chart-state="chart"
    :index="index"
    :chart-count="charts.length"
    @remove-chart="removeChart"
    @move-up="moveChartUp"
    @move-down="moveChartDown"
  />

  <va-card class="mb-2">
    <va-card-content>
      <add-chart-drop-down :series-info="seriesInfo.groups" @add-chart="addChart" />
    </va-card-content>
  </va-card>
</template>

<script lang="ts">
  import { useI18n } from 'vue-i18n'
  import { defineComponent, ref, ShallowReactive, shallowReactive } from 'vue'
  import propertyService from '../../../services/fairyNode/PropertyService'
  import { ChartSeries, ChartSeriesInfo } from '../../../services/fairyNode/PropertyService'

  import { storeToRefs } from 'pinia'
  import { useGlobalStore } from '../../../stores/global-store'

  import ChartCard from './ChartCard.vue'
  import DurationSelector from './controls/DurationSelector.vue'
  import AddChartDropDown from './controls/AddChartDropDown.vue'
  import { ChartState } from './ChartState'

  export default defineComponent({
    components: {
      ChartCard,
      DurationSelector,
      AddChartDropDown,
    },
    // props: {},
    setup() {
      const { t } = useI18n()
      const charts = ref(new Array<ShallowReactive<ChartState>>())
      const seriesInfo = ref(<ChartSeriesInfo>{})

      const globalStore = useGlobalStore()
      const { addedCharts, chartDuration } = storeToRefs(globalStore)

      return {
        t,
        charts,
        seriesInfo,
        globalStore,
        addedCharts,
        chartDuration,
      }
    },
    data() {
      return { timerId: 0 }
    },
    // watch: {},
    mounted() {
      this.refreshSeries()
      if (this.timerId == 0) {
        this.timerId = window.setInterval(() => {
          this.updateCharts()
        }, 10 * 1000)
      }
    },
    unmounted() {
      if (this.timerId != 0) {
        window.clearInterval(this.timerId)
        this.timerId = 0
      }
    },
    methods: {
      uniqueID(): number {
        return Math.floor(Math.random() * Date.now())
      },
      addChart(id: string) {
        if (this.seriesInfo.groups) {
          for (var index in this.seriesInfo.groups) {
            var entry: ChartSeries = this.seriesInfo.groups[index]
            if (entry.id == id) {
              this.charts.push(shallowReactive(new ChartState(entry, this.chartDuration, this.uniqueID())))
              this.UpdateChartsStore()
              return
            }
          }
        }
      },
      removeChart(index: number) {
        this.charts.splice(index, 1)
        this.UpdateChartsStore()
      },
      removeAllCharts() {
        this.charts.length = 0
      },
      min(a: any, b: any) {
        return a > b ? b : a
      },

      UpdateChartsStore() {
        var lst: string[] = []
        this.charts.forEach((e) => {
          lst.push(e.chartSeries.id)
        })
        this.globalStore.setAddedCharts(lst)
      },

      updateCharts() {
        this.charts.forEach((e) => e.update())
      },
      reloadCharts() {
        this.removeAllCharts()
        this.addedCharts.forEach((id) => this.addChart(id))
      },
      updateChartDuration() {
        this.charts.forEach((e) => e.setDuration(this.chartDuration))
      },

      swap(arr: any, from: number, to: number) {
        arr.splice(from, 1, arr.splice(to, 1, arr[from])[0])
      },

      moveChartUp(state: ChartState) {
        var index = this.charts.indexOf(state)
        if (index > 0) {
          this.swap(this.charts, index, index - 1)
          this.UpdateChartsStore()
        }
      },
      moveChartDown(state: ChartState) {
        var index = this.charts.indexOf(state)
        if (index < this.charts.length - 1) {
          this.swap(this.charts, index, index + 1)
          this.UpdateChartsStore()
        }
      },

      refreshSeries() {
        propertyService.chartSeries().then((data) => {
          var sortFunc = function (a: any, b: any) {
            var a_name = a.name || ''
            var b_name = b.name || ''
            return a_name.toLowerCase().localeCompare(b_name.toLowerCase())
          }

          if (data.device) data.device.sort(sortFunc)
          if (data.groups) data.groups.sort(sortFunc)
          if (data.units) data.units.sort(sortFunc)

          this.seriesInfo = data
          this.reloadCharts()
        })
        // .catch(() => {})
        // .finally(() => {})
      },
    },
  })
</script>

<style lang="scss">
  .chart_card {
    width: 100%;
  }
</style>
