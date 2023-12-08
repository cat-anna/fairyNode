import { defineAsyncComponent } from 'vue'
export const chartTypesMap = {
  pie: defineAsyncComponent(() => import('./chart-types/PieChart.vue')),
  doughnut: defineAsyncComponent(() => import('./chart-types/DoughnutChart.vue')),
  bubble: defineAsyncComponent(() => import('./chart-types/BubbleChart.vue')),
  line: defineAsyncComponent(() => import('./chart-types/LineChart.vue')),
  bar: defineAsyncComponent(() => import('./chart-types/BarChart.vue')),
  'horizontal-bar': defineAsyncComponent(() => import('./chart-types/HorizontalBarChart.vue')),
}
