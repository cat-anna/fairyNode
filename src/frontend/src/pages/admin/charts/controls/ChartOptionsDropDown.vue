<template>
  <va-dropdown trigger="hover" class="" preset="primary" placement="left">
    <template #anchor>
      <va-button preset="plain" size="small">
        <va-icon name="material-icons-settings" />
      </va-button>
    </template>

    <va-dropdown-content>
      <va-scroll-container class="max-h-[400px]" vertical>
        <va-list>
          <div v-for="(item, index) in optList" :key="index">
            <va-list-item v-if="item.signal" class="flex py-1">
              <va-popover :message="(item.hint && t(item.hint)) || ''" placement="left" :disabled="item.hint == ''">
                <va-button plain @click="handleAction(item)">
                  <va-icon :name="item.icon" />
                  {{ t(item.label) }}
                </va-button>
              </va-popover>
            </va-list-item>
            <va-divider v-else />
          </div>
        </va-list>
      </va-scroll-container>
    </va-dropdown-content>
  </va-dropdown>
</template>

<script lang="ts">
  import { useI18n } from 'vue-i18n'
  import { defineComponent, ref } from 'vue'
  import { ChartSeries } from '../../../../services/fairyNode/PropertyService'

  const Options = [
    { label: 'charts.edit', hint: '', icon: 'material-icons-edit', signal: 'edit' },
    {},
    { label: 'charts.move_up', hint: '', icon: 'material-icons-arrow_upward', signal: 'moveUp' },
    { label: 'charts.move_down', hint: '', icon: 'material-icons-arrow_downward', signal: 'moveDown' },
    {},
    { label: 'charts.remove_chart', hint: '', icon: 'material-icons-delete', signal: 'removeChart' },
  ]

  export default defineComponent({
    props: {
      seriesInfo: {
        required: false,
        default: null,
        type: Array<ChartSeries>,
      },
    },
    emits: ['moveUp', 'moveDown', 'removeChart', 'edit'],
    setup(props, { emit }) {
      const { t } = useI18n()
      const optList = ref(Options)
      return { t, emit, optList }
    },
    methods: {
      handleAction(item: any) {
        this.emit(item.signal, item)
      },
    },
  })
</script>

<style lang="scss"></style>
