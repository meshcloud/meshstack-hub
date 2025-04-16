import { CommonModule } from '@angular/common';
import { Component, OnDestroy, OnInit } from '@angular/core';
import { ActivatedRoute } from '@angular/router';
import { NgbModal } from '@ng-bootstrap/ng-bootstrap';
import { Observable, Subscription, map, switchMap } from 'rxjs';

import { PlatformType } from 'app/core';
import { BreadCrumbService } from 'app/shared/breadcrumb/bread-crumb.service';
import { BreadcrumbItem } from 'app/shared/breadcrumb/breadcrumb';
import { BreadcrumbComponent } from 'app/shared/breadcrumb/breadcrumb.component';
import { TemplateService } from 'app/shared/template';

import { ImportDialogComponent } from './import-dialog/import-dialog.component';

interface TemplateDetailsVm {
  imageUrl: string | null;
  name: string;
  platformType: PlatformType;
  description: string;
  howToUse: string;
  source: string;
  backplaneUrl: string | null;
}

@Component({
  selector: 'mst-template-details',
  imports: [CommonModule, BreadcrumbComponent],
  templateUrl: './template-details.component.html',
  styleUrl: './template-details.component.scss',
  standalone: true
})
export class TemplateDetailsComponent implements OnInit, OnDestroy {
  public template$!: Observable<TemplateDetailsVm>;

  public breadcrumbs$!: Observable<BreadcrumbItem[]>;

  public backPath$!: Observable<string>;

  public copyLabel = 'Copy';

  private routeSubscription!: Subscription;

  constructor(
    private route: ActivatedRoute,
    private templateService: TemplateService,
    private modalService: NgbModal,
    private breadcrumbService: BreadCrumbService
  ) { }

  public ngOnInit(): void {
    this.initializeTemplate();
    this.breadcrumbs$ = this.route.paramMap.pipe(switchMap(x => this.breadcrumbService.getBreadcrumbs(x)));
    this.backPath$ = this.breadcrumbs$.pipe(map(breadcrumbs => {
      const secondLastBreadcrumb = breadcrumbs[breadcrumbs.length - 2].routePath;

      return secondLastBreadcrumb ? secondLastBreadcrumb : '/';
    }));
  }

  public ngOnDestroy(): void {
    this.routeSubscription.unsubscribe();
  }

  public copyToClipboard(value: string): void {
    navigator.clipboard.writeText(value)
      .then(() => this.updateCopyLabel());
  }

  public open(template: TemplateDetailsVm): void {
    const modulePath = this.extractModulePath(template.source);

    if (!modulePath) {
      // eslint-disable-next-line no-console
      console.error('Module path not found in source URL');

      return;
    }

    const component = this.modalService.open(ImportDialogComponent, { size: 'lg', centered: true }).componentInstance;
    component.name = template.name;
    component.modulePath = modulePath;
  }

  private extractModulePath(source: string): string {
    const regex = /modules\/[^/]+\/[^/]+/;
    const match = source.match(regex);

    return match ? match[0] : '';
  }

  private initializeTemplate(): void {
    this.routeSubscription = this.route.paramMap.subscribe(params => {
      const id = params.get('id');

      if (!id) {
        throw new Error('Template ID is required');
      }

      this.template$ = this.templateService.getTemplateById(id)
        .pipe(
          map(template => ({
            ...template,
            imageUrl: template.logo,
            source: template.buildingBlockUrl,
            howToUse: template.howToUse
          }))
        );
    });
  }

  private updateCopyLabel(): void {
    this.copyLabel = 'Copied';
    setTimeout(() => {
      this.copyLabel = 'Copy';
    }, 1000);
  }

}
