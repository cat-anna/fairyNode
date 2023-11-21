<template>
  <component :is="chartComponent" ref="chart" class="va-chart" :chart-options="options" :chart-data="data" />
</template>

<script setup lang="ts">
  import { computed, ref } from 'vue'
  import { chartTypesMap } from './vaChartConfigs'
  import { TChartData } from '../../data/types'
  import { ChartOptions } from 'chart.js'
  import 'chartjs-adapter-luxon'

  const props = defineProps<{
    data: TChartData
    options?: ChartOptions<'line' | 'bar' | 'bubble' | 'doughnut' | 'pie'>
    type: keyof typeof chartTypesMap
  }>()

  const chart = ref()
  const chartComponent = computed(() => chartTypesMap[props.type])
</script>

<style lang="scss">
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
      min-height: 320px;
    }
  }
</style>
