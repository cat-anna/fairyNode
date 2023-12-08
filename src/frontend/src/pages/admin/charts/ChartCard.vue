<template>
  <va-card class="mb-2">
    <div v-if="editing">
      <chart-editor :series-id="chartState.getSeriesIdList()" :name="chartState.name" @cancel-edit="cancelEdit" @accept-edit="acceptEdit" />
    </div>
    <div v-else>
      <va-card-title>
        <div class="text-sm">
          {{ chartState.name }}
        </div>
        <div class="va-spacer"></div>

        <va-popover placement="left">
          <va-icon name="material-icons-info_outline" color="primary" />
          <template #body>
            <p v-for="line in genInfoMessage()" :key="line">{{ line }}</p>
          </template>
        </va-popover>
        <chart-options-drop-down
          @move-up="propagateOptionsAction"
          @move-down="propagateOptionsAction"
          @remove-chart="propagateOptionsAction"
          @edit="beginChartEdit"
        />
      </va-card-title>
      <va-card-content :class="'chart_count_' + Math.min(chartCount, 3)">
        <div v-if="ready" class="va-chart">
          <Line v-once ref="chartInstance" :options="chartConfig" :data="chartState.chartData" />
        </div>
        <busy-spinner v-else />
      </va-card-content>
    </div>
  </va-card>
</template>

<script lang="ts">
  import { useI18n } from 'vue-i18n'
  import { defineComponent, ref, Ref } from 'vue'

  import { Line } from 'vue-chartjs'
  import ChartOptionsDropDown from './controls/ChartOptionsDropDown.vue'
  import ChartEditor from './controls/ChartEditor.vue'

  import { ChartState } from './ChartState'
  import { chartConfig } from './ChartConfig'
  import './ChartJsUtils'

  export default defineComponent({
    components: {
      Line,
      ChartOptionsDropDown,
      ChartEditor,
    },
    props: {
      chartState: {
        required: true,
        type: ChartState,
      },
      index: {
        required: true,
        type: Number,
      },
      chartCount: {
        required: true,
        type: Number,
      },
    },
    emits: ['moveUp', 'moveDown', 'removeChart', 'changed'],
    setup(props, { emit }) {
      const { t } = useI18n()
      const chartInstance: Ref<typeof Line | null> = ref(null)
      const ready = ref(false)
      const editing = ref(false)
      return { t, emit, chartInstance, chartConfig: chartConfig, ready, editing }
    },
    watch: {},
    mounted() {
      this.chartState.setUpdateFunc((v: boolean) => {
        this.ready = v
        if (this.ready && this.chartInstance) this.chartInstance.chart.update()
      })
    },
    methods: {
      reload() {
        // this.chartState.reload()
      },
      beginChartEdit() {
        this.editing = true
      },
      cancelEdit() {
        this.editing = false
      },
      acceptEdit(seriesId: string[], newName: string) {
        console.log(seriesId)
        this.editing = false
        this.chartState.reset(seriesId, newName)
        this.emit('changed', this.chartState)
      },
      propagateOptionsAction(action: any) {
        this.emit(action.signal, this.chartState)
      },
      genInfoMessage() {
        var lines: string[] = []
        var samples = this.t('charts.samples')

        this.chartState.chartData.datasets.forEach((entry) => {
          if (entry.label) {
            lines.push(entry.label + ' - ' + entry.data.length + ' ' + samples)
          }
        })

        return lines
      },
    },
  })
</script>

<style lang="scss">
  .chart_count_1 {
    height: 50vh;
  }

  .chart_count_2 {
    height: 35vh;
  }

  .chart_count_3 {
    height: 20vh;
  }

  .va-chart {
    width: 100%;
    height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;

    > * {
      height: 100%;
      width: 100%;
    }

    canvas {
      width: 100%;
      height: auto;
    }
  }
</style>
