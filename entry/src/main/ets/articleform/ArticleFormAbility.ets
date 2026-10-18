import { common } from '@kit.AbilityKit';
import type { Want } from '@kit.AbilityKit';
import { formBindingData, FormExtensionAbility, formInfo, formProvider } from '@kit.FormKit';
import type { BusinessError } from '@kit.BasicServicesKit';
import hilog from '@ohos.hilog';
import { ArticleCardFormData, ArticleCardItem } from '../models/ArticleCardItem';
import { ArticleCardStore } from '../services/ArticleCardStore';
import { ArticleCardPublisher } from '../services/ArticleCardPublisher';
import { ArticleCardImages, ArticleCardImageBinding } from '../services/ArticleCardImages';

const DOMAIN = 0xFF00;
const TAG = 'HarmonyX-ArticleForm';
const FORM_NAME: string = 'ArticleServiceCard';
const DEFAULT_DIMENSION: string = '2*4';

export default class ArticleFormAbility extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    const rawName: Object | undefined = want.parameters?.[formInfo.FormParam.NAME_KEY];
    const rawFormId: Object | undefined = want.parameters?.[formInfo.FormParam.IDENTITY_KEY];
    const rawDimension: Object | undefined = want.parameters?.[formInfo.FormParam.DIMENSION_KEY];
    const name: string = typeof rawName === 'string' ? rawName : '';
    const formId: string = typeof rawFormId === 'string' ? rawFormId : '';
    const dimension: string = ArticleFormAbility.dimension(rawDimension);
    if (name.length > 0 && name !== FORM_NAME) {
      return ArticleFormAbility.emptyData(this.context, dimension);
    }
    ArticleCardPublisher.register(this.context, formId, dimension);
    formProvider.getFormRect(formId).then((rect: formInfo.Rect): void => {
      ArticleCardPublisher.updateGeometry(this.context, formId, rect.width, rect.height, dimension);
    }).catch((): void => {
    });
    return ArticleFormAbility.data(this.context, dimension);
  }

  onUpdateForm(formId: string): void {
    formProvider.getFormRect(formId).then((rect: formInfo.Rect): void => {
      const dimension: string =
        ArticleCardPublisher.updateGeometry(this.context, formId, rect.width, rect.height);
      const images: ArticleCardImageBinding = ArticleCardImages.bind(this.context,
        ArticleCardStore.loadForWidget(this.context), dimension, ArticleCardStore.selectedSource(this.context));
      formProvider.updateForm(formId, images.bindingData()).catch((error: BusinessError): void => {
        hilog.debug(DOMAIN, TAG, 'form update failed: %{public}s', error.message);
      }).finally((): void => images.close());
    }).catch((error: BusinessError): void => {
      hilog.debug(DOMAIN, TAG, 'form rect failed: %{public}s', error.message);
      const images: ArticleCardImageBinding = ArticleCardImages.bind(this.context,
        ArticleCardStore.loadForWidget(this.context), DEFAULT_DIMENSION, ArticleCardStore.selectedSource(this.context));
      formProvider.updateForm(formId, images.bindingData()).catch((updateError: BusinessError): void => {
        hilog.debug(DOMAIN, TAG, 'form update failed: %{public}s', updateError.message);
      }).finally((): void => images.close());
    });
  }

  onRemoveForm(formId: string): void {
    ArticleCardPublisher.unregister(this.context, formId);
  }

  onSizeChanged(formId: string, newDimension: formInfo.FormDimension, newRect: formInfo.Rect): void {
    const dimension: string = ArticleFormAbility.dimension(newDimension);
    ArticleCardPublisher.updateGeometry(this.context, formId, newRect.width, newRect.height, dimension);
    const images: ArticleCardImageBinding = ArticleCardImages.bind(this.context,
      ArticleCardStore.loadForWidget(this.context), dimension, ArticleCardStore.selectedSource(this.context));
    formProvider.updateForm(formId, images.bindingData()).catch((error: BusinessError): void => {
      hilog.debug(DOMAIN, TAG, 'form resize failed: %{public}s', error.message);
    }).finally((): void => images.close());
  }

  onAcquireFormState(_want: Want): formInfo.FormState {
    return formInfo.FormState.READY;
  }

  private static dimension(value: Object | undefined): string {
    if (value === formInfo.FormDimension.Dimension_2_2 || value === '2*2' || value === '2') {
      return '2*2';
    }
    if (value === formInfo.FormDimension.Dimension_4_4 || value === '4*4' || value === '4') {
      return '4*4';
    }
    return DEFAULT_DIMENSION;
  }

  private static data(context: common.Context, dimension: string): formBindingData.FormBindingData {
    const items: ArticleCardItem[] = ArticleCardStore.loadForWidget(context);
    const source: string = ArticleCardStore.selectedSource(context);
    // onAddForm transfers these descriptors after returning. Form Kit owns
    // that initial transaction; the short-lived extension releases its FDs
    // when destroyed, as in the official image-update example.
    return ArticleCardImages.bind(context, items, dimension, source).bindingData();
  }

  private static emptyData(context: common.Context, dimension: string): formBindingData.FormBindingData {
    const items: ArticleCardItem[] = [];
    const source: string = ArticleCardStore.selectedSource(context);
    return formBindingData.createFormBindingData(new ArticleCardFormData(items, dimension, source));
  }
}
