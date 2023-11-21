<template>
  <Bar :options="chartOptions" :data="props.chartData" />
</template>

<script setup lang="ts">
  import { Bar } from 'vue-chartjs'
  import {
    Chart as ChartJS,
    Title,
    Tooltip,
    Legend,
    BarElement,
    LinearScale,
    CategoryScale,
    ChartOptions,
  } from 'chart.js'
  import { TBarChartData } from '../../../data/types'

  ChartJS.register(Title, Tooltip, Legend, BarElement, LinearScale, CategoryScale)

  const props = defineProps<{
    chartData: TBarChartData
    chartOptions?: ChartOptions<'bar'>
  }>()
</script>
