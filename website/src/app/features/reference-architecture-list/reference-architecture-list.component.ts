import { CommonModule } from '@angular/common';
import { Component, OnInit } from '@angular/core';
import { Observable, forkJoin, map } from 'rxjs';

import { ReferenceArchitecture } from 'app/core';
import { BreadcrumbComponent } from 'app/shared/breadcrumb';
import { BreadcrumbItem } from 'app/shared/breadcrumb/breadcrumb';
import { CardComponent } from 'app/shared/card';
import { Platform, PlatformService } from 'app/shared/platform';
import { ReferenceArchitectureService } from 'app/shared/reference-architecture';

interface RefArchCard {
  id: string;
  name: string;
  description: string;
  cloudProviders: string[];
  buildingBlockCount: number;
  platformLogos: { platformType: string; imageUrl: string }[];
}

@Component({
  selector: 'mst-reference-architecture-list',
  imports: [CommonModule, CardComponent, BreadcrumbComponent],
  templateUrl: './reference-architecture-list.component.html',
  styleUrl: './reference-architecture-list.component.scss',
  standalone: true
})
export class ReferenceArchitectureListComponent implements OnInit {
  public cards$!: Observable<RefArchCard[]>;

  public breadcrumbs: BreadcrumbItem[] = [
    { label: 'Home', routePath: '/' },
    { label: 'Reference Architectures', routePath: '' }
  ];

  constructor(
    private refArchService: ReferenceArchitectureService,
    private platformService: PlatformService
  ) {}

  public ngOnInit(): void {
    this.cards$ = forkJoin({
      archs: this.refArchService.getAll(),
      platforms: this.platformService.getAllPlatforms()
    }).pipe(
      map(({ archs, platforms }) => archs.map(arch => this.toCard(arch, platforms)))
    );
  }

  private toCard(arch: ReferenceArchitecture, platforms: Platform[]): RefArchCard {
    return {
      id: arch.id,
      name: arch.name,
      description: arch.description,
      cloudProviders: arch.cloudProviders,
      buildingBlockCount: arch.buildingBlocks.length,
      platformLogos: arch.cloudProviders.map(cp => ({
        platformType: cp,
        imageUrl: platforms.find(p => p.platformType === cp)?.logo ?? 'assets/meshstack-logo.png'
      }))
    };
  }
}


