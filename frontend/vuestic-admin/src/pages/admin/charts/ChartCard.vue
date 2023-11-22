<template>
  <va-card class="mb-2 chart_card">
    <va-card-title>
      <div>{{ chartState.chartSeries.name }}</div>
      <div class="va-spacer"></div>
      <VaPopover placement="left">
        <va-icon name="material-icons-info_outline" />
        <template #body>
          <p v-for="line in genInfoMessage()" :key="line">{{ line }}</p>
        </template>
      </VaPopover>
      <chart-options-drop-down @move-up="propagateOptionsAction" @move-down="propagateOptionsAction" @remove-chart="propagateOptionsAction" />
    </va-card-title>

    <va-card-content class="chart_content" :class="'chart_count_' + min(chartCount, 3)">
      <div v-if="ready" class="va-chart">
        <Line v-once ref="chartInstance" :options="chartConfig" :data="chartState.chartData" />
      </div>
      <busy-spinner v-else />
    </va-card-content>
  </va-card>
</template>

<script lang="ts">
  import { useI18n } from 'vue-i18n'
  import { defineComponent, ref, Ref } from 'vue'

  import { Line } from 'vue-chartjs'
  import { ChartOptions } from 'chart.js'

  import { ChartState } from './ChartState'
  import ChartOptionsDropDown from './controls/ChartOptionsDropDown.vue'
  import './ChartJsUtils'

  const chartConfig: ChartOptions<'line'> = {
    maintainAspectRatio: false,
    animation: {
      loop: false,
    },

    plugins: {
      legend: {
        position: 'bottom',
        labels: {
          font: {
            // @ts-ignore
            color: '#34495e',
            family: 'sans-serif',
            size: 14,
          },
          usePointStyle: true,
        },
      },
      tooltip: {
        bodyFont: {
          size: 14,
          family: 'sans-serif',
        },
        boxPadding: 4,
      },
    },
    elements: {
      point: {
        radius: 2,
        hoverRadius: 5,
      },
    },
    scales: {
      x: {
        // @ts-ignore
        type: 'time',
        time: {},
        ticks: {
          // @ts-ignore
          fontColor: 'rgb(150, 150, 150)',
          maxTicksLimit: 10,
        },
        scaleLabel: {
          fontColor: 'rgb(150, 150, 150)',
          display: true,
        },
      },
      y: {
        // @ts-ignore
        type: 'linear',
        // min: 0,
        // max: 2000,
        ticks: {
          // @ts-ignore
          fontColor: 'rgb(150, 150, 150)',
        },
        scaleLabel: {
          fontColor: 'rgb(150, 150, 150)',
          display: true,
          labelString: 'value',
        },
      },
    },
  }

  export default defineComponent({
    components: {
      Line,
      ChartOptionsDropDown,
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
    emits: ['moveUp', 'moveDown', 'removeChart'],
    setup(props, { emit }) {
      const { t } = useI18n()
      const chartInstance: Ref<typeof Line | null> = ref(null)
      const ready = ref(false)
      return { t, emit, chartInstance, chartConfig: chartConfig, ready }
    },
    watch: {},
    mounted() {
      this.chartState.setUpdateFunc((v: boolean) => {
        this.ready = v
        if (this.ready && this.chartInstance) this.chartInstance.chart.update()
      })
    },
    methods: {
      min(a: any, b: any): any {
        return a > b ? b : a
      },
      reload() {
        this.chartState.reload()
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
  // .chart_content {
  // height: 400px;
  // }

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
