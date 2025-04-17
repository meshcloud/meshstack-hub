import { CommonModule } from '@angular/common';
import { Component, OnDestroy, OnInit } from '@angular/core';
import { ActivatedRoute } from '@angular/router';
import { NgbModal } from '@ng-bootstrap/ng-bootstrap';
import { Observable, Subscription, map, of, switchMap } from 'rxjs';

import { PlatformType } from 'app/core';
import { BreadcrumbItem } from 'app/shared/breadcrumb/breadcrumb';
import { BreadcrumbComponent } from 'app/shared/breadcrumb/breadcrumb.component';
import { PlatformService } from 'app/shared/platform-logo';
import { TemplateService } from 'app/shared/template';

import { ImportDialogComponent } from './import-dialog/import-dialog.component';

interface TemplateDetailsVm {
  imageUrl: string | null;
  name: string;
  platformType: PlatformType;
  description: string;
  howToUse: string;
  source: string;
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

  public copyLabel = 'Copy';

  private routeSubscription!: Subscription;

  constructor(
    private route: ActivatedRoute,
    private templateService: TemplateService,
    private platformService: PlatformService,
    private modalService: NgbModal
  ) { }

  public ngOnInit(): void {
    this.initializeBreadcrumbs();
    this.initializeTemplate();
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

  private initializeBreadcrumbs(): void {
    this.breadcrumbs$ = this.route.paramMap.pipe(
      switchMap(params => {
        const id = params.get('id');
        const type = params.get('type');

        if (!id) {
          throw new Error('Template ID is required');
        }

        return this.getPlatformData(type)
          .pipe(
            switchMap((platformName) =>
              this.templateService.getTemplateById(id)
                .pipe(
                  map(template => this.buildBreadcrumbs(template.name, platformName, type))
                )
            )
          );
      })
    );
  }

  private getPlatformData(type: string | null): Observable<string|null> {
    if (!type) {
      return of(null);
    }

    return this.platformService.getPlatformData(type)
      .pipe(
        map(x => x.name)
      );
  }

  private buildBreadcrumbs(
    templateName: string,
    platformName: string | null,
    type: string | null,
  ): BreadcrumbItem[] {
    const breadcrumbs: BreadcrumbItem[] = [{ label: 'Overview', routePath: '/' }];

    if (platformName) {
      breadcrumbs.push({ label: platformName, routePath: `/platforms/${type}` });
    }

    breadcrumbs.push({ label: templateName, routePath: '' });

    return breadcrumbs;
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
            source: template.githubUrls.https,
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
