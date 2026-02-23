import { CommonModule } from '@angular/common';
import { Component, OnDestroy, OnInit } from '@angular/core';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { Dialog } from '@angular/cdk/dialog';
import { Observable, Subscription, map, switchMap, of } from 'rxjs';

import { BreadCrumbService } from 'app/shared/breadcrumb/bread-crumb.service';
import { BreadcrumbItem } from 'app/shared/breadcrumb/breadcrumb';
import { BreadcrumbComponent } from 'app/shared/breadcrumb/breadcrumb.component';
import { CardComponent } from 'app/shared/card';
import { TemplateService } from 'app/shared/template';
import { extractLogoColor } from 'app/shared/util/logo-color.util';

import { ImportDialogComponent } from './import-dialog/import-dialog.component';
import { HighlightDirective } from 'app/shared/directives';

const DEFAULT_HEADER_BG_COLOR = 'rgba(203,213,225,0.3)';

interface TemplateDetailsVm {
  imageUrl: string | null;
  name: string;
  platformType: string;
  description: string;
  howToUse: string;
  source: string;
  backplaneUrl: string | null;
  terraformSnippet?: string;
}

@Component({
  selector: 'mst-template-details',
  imports: [CommonModule, BreadcrumbComponent, CardComponent, RouterLink, HighlightDirective],
  templateUrl: './template-details.component.html',
  styleUrl: './template-details.component.scss',
  standalone: true
})
export class TemplateDetailsComponent implements OnInit, OnDestroy {
  public template$!: Observable<TemplateDetailsVm>;

  public breadcrumbs$!: Observable<BreadcrumbItem[]>;

  public backPath$!: Observable<string>;

  public copyLabel = 'Copy';

  public copiedTerraform = false;

  public headerBgColor$!: Observable<string>;

  private routeSubscription!: Subscription;

  constructor(
    private route: ActivatedRoute,
    private templateService: TemplateService,
    private dialog: Dialog,
    private breadcrumbService: BreadCrumbService
  ) { }

  public ngOnInit(): void {
    this.initializeTemplate();
    this.breadcrumbs$ = this.route.paramMap.pipe(switchMap(x => this.breadcrumbService.getBreadcrumbs(x)));
    this.backPath$ = this.breadcrumbs$.pipe(map(breadcrumbs => {
      const secondLastBreadcrumb = breadcrumbs[breadcrumbs.length - 2].routePath;

      return secondLastBreadcrumb ? secondLastBreadcrumb : '/';
    }));

    // Reactive header background color
    this.headerBgColor$ = this.template$.pipe(
      switchMap(template =>
        template && template.imageUrl
          ? extractLogoColor(template.imageUrl).pipe(
              map(color => color || DEFAULT_HEADER_BG_COLOR)
            )
          : of(DEFAULT_HEADER_BG_COLOR)
      )
    );
  }

  public ngOnDestroy(): void {
    this.routeSubscription.unsubscribe();
  }

  public copyToClipboard(value: string): void {
    navigator.clipboard.writeText(value)
      .then(() => this.updateCopyLabel());
  }

  public copyTerraform(value: string): void {
    navigator.clipboard.writeText(value)
      .then(() => {
        this.copiedTerraform = true;
        setTimeout(() => {
          this.copiedTerraform = false;
        }, 2000);
      });
  }

  public open(template: TemplateDetailsVm): void {
    const modulePath = this.extractModulePath(template.source);

    if (!modulePath) {
      // eslint-disable-next-line no-console
      console.error('Module path not found in source URL');

      return;
    }

    this.dialog.open(ImportDialogComponent, {
      width: '600px',
      data: { name: template.name, modulePath }
    });
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
            howToUse: template.howToUse,
            terraformSnippet: template.terraformSnippet
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
