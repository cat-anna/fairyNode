<template>
  <va-card class="mb-2">
    <va-card-content>
      <orbit-spinner v-if="seriesInfo.length == 0" />
      <va-dropdown v-if="seriesInfo.length > 0" trigger="hover" class="mr-2 mb-2" preset="primary">
        <template #anchor>
          <va-button>
            <va-icon :name="'material-icons-add'" />
            {{ t('charts.add_chart') }}
          </va-button>
        </template>

        <va-dropdown-content>
          <va-scroll-container class="max-h-[400px]" vertical>
            <va-list>
              <va-list-item v-for="series in seriesInfo" :key="series.id" class="flex py-1">
                <va-button plain @click="$emit('AddChart', series.id)">
                  {{ series.name }}
                </va-button>
              </va-list-item>
            </va-list>
          </va-scroll-container>
        </va-dropdown-content>
      </va-dropdown>
    </va-card-content>
  </va-card>
</template>

<script lang="ts">
  import { useI18n } from 'vue-i18n'
  import { defineComponent } from 'vue'
  import { ChartSeries } from '../../../services/fairyNode/PropertyService'
  import { OrbitSpinner } from 'epic-spinners'

  export default defineComponent({
    components: {
      OrbitSpinner,
    },
    props: {
      seriesInfo: {
        required: true,
        type: Array<ChartSeries>,
      },
    },
    emits: ['AddChart'],
    setup() {
      const { t } = useI18n()
      return { t }
    },
    data() {
      return {}
    },
    // watch: {},
    // mounted() {},
    // unmounted() {},
    // methods: {},
  })
</script>

<style lang="scss">
  .chart_card {
    width: 100%;
  }
</style>
