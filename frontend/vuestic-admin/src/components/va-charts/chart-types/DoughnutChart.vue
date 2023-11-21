<template>
  <Doughnut :options="chartOptions" :data="props.chartData" />
</template>

<script setup lang="ts">
  import { Doughnut } from 'vue-chartjs'
  import { Chart as ChartJS, Title, Tooltip, Legend, ArcElement, CategoryScale, ChartOptions } from 'chart.js'
  import { TDoughnutChartData } from '../../../data/types'

  ChartJS.register(Title, Tooltip, Legend, ArcElement, CategoryScale)

  const props = defineProps<{
    chartData: TDoughnutChartData
    chartOptions?: ChartOptions<'doughnut'>
  }>()
</script>
