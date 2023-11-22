<template>
  <va-dropdown trigger="hover" class="mr-2 mb-2" preset="primary">
    <template #anchor>
      <va-button>
        <va-icon :name="'material-icons-add'" />
        {{ t('charts.add_chart') }}
      </va-button>
    </template>

    <va-dropdown-content>
      <busy-spinner v-if="seriesInfo.length == 0" />
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
</template>

<script lang="ts">
  import { useI18n } from 'vue-i18n'
  import { defineComponent } from 'vue'
  import { ChartSeries } from '../../../../services/fairyNode/PropertyService'

  export default defineComponent({
    // components: { },
    props: {
      seriesInfo: {
        required: false,
        default: undefined,
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
  })
</script>

<style lang="scss"></style>
