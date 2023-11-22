<template>
  <Line :options="chartOptions" :data="chartData" />
</template>

<script setup lang="ts">
  import { Line } from 'vue-chartjs'
  // eslint-disable-next-line
  import {
    Chart as ChartJS,
    Title,
    Tooltip,
    Legend,
    LineElement,
    LinearScale,
    PointElement,
    CategoryScale,
    Filler,
    TimeScale,
    Colors,
    ChartOptions,
  } from 'chart.js'
  import { TLineChartData } from '../../../data/types'

  ChartJS.register(Colors, TimeScale, Title, Tooltip, Legend, LineElement, LinearScale, PointElement, CategoryScale, Filler)

  defineProps<{
    chartData: TLineChartData
    chartOptions?: ChartOptions<'line'>
  }>()
</script>
